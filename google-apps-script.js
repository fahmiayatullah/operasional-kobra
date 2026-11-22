/**
 * =========================================================================
 * BACKEND API GOOGLE APPS SCRIPT — SISTEM OPERASIONAL PERCETAKAN KOBRA HITAM
 * (SINKRONISASI 2-ARAH REAL-TIME ANTAR HP, LAPTOP, DAN KOMPUTER KASIR)
 * =========================================================================
 * 
 * PANDUAN CEPAT PEMASANGAN:
 * 1. Buka spreadsheet Google Anda:
 *    https://docs.google.com/spreadsheets/d/17fNVMEWJxoCLs941Z1sLtlclAq8dlGCov_-TxW26ZXQ/edit
 * 2. Klik menu "Ekstensi" (Extensions) > "Apps Script".
 * 3. Hapus semua kode bawaan, lalu tempel SELURUH KODE di file ini.
 * 4. Klik ikon "Simpan" (Ctrl+S).
 * 5. Klik tombol "Deploy" (Terapkan) di kanan atas > "Penerapan baru" (New deployment).
 * 6. Pilih jenis: "Web app" (Aplikasi web) via ikon gerigi.
 * 7. Konfigurasi:
 *    - Description: API Kobra Hitam Multi-Device
 *    - Execute as: Me (email Google Anda)
 *    - Who has access: Anyone (Siapa saja)  <-- WAJIB agar HP & PC kasir bisa kirim data!
 * 8. Klik "Deploy" > "Izinkan Akses" (Authorize access).
 * 9. Salin URL Web App yang berakhiran "/exec", lalu masukkan ke menu
 *    "Pengaturan & Integrasi Sheets" di aplikasi web Anda!
 * =========================================================================
 */

const SS = SpreadsheetApp.getActiveSpreadsheet();

// Definisi Header untuk sheet operasional yang dibuat otomatis jika belum ada
const HEADERS = {
  Transaksi: ['id', 'invoiceNo', 'date', 'customerName', 'totalItems', 'subtotal', 'discountAmount', 'total', 'totalHpp', 'labaKotor', 'paymentMethod', 'notes', 'itemsJson'],
  Transaksi_Item: ['invoiceNo', 'refId', 'nama', 'type', 'qty', 'harga', 'hppUnit', 'subtotal', 'date'],
  Jurnal_Keuangan: ['id', 'date', 'type', 'refNo', 'description', 'direction', 'amount', 'hpp', 'paymentMethod', 'metaJson'],
  Mutasi_Stok: ['id', 'date', 'type', 'source', 'productId', 'productName', 'qty', 'stockBefore', 'stockAfter', 'refNo', 'notes'],
  Pengaturan_Web: ['key', 'value', 'updatedAt']
};

/**
 * Handle GET Request (Mengambil data & Ping dari Web ke Spreadsheet)
 * Mendukung JSONP via parameter ?callback=... untuk mencegah masalah CORS di semua perangkat.
 */
function doGet(e) {
  try {
    const params = (e && e.parameter) || {};
    const action = params.action || 'getAll';
    const callback = params.callback;
    let responseData = {};

    initAllSheets();

    if (action === 'ping') {
      responseData = {
        pong: true,
        sheetName: SS.getName(),
        time: new Date().toISOString(),
        version: '2.0.0'
      };
    } else if (action === 'getAll') {
      // Ambil transaksi, jurnal, mutasi stok, dan harga kustom
      const sales = getSalesWithItems();
      const journal = getSheetRecords('Jurnal_Keuangan').map(parseJournalRow);
      const stockMovements = getSheetRecords('Mutasi_Stok');
      const customPrices = getSettingRecord('customPrices');
      const shopSettings = getSettingRecord('shopSettings');

      responseData = {
        sales: sales,
        journal: journal,
        stockMovements: stockMovements,
        customPrices: customPrices || {},
        shopSettings: shopSettings || null,
        serverTime: new Date().toISOString()
      };
    } else if (action === 'getSales') {
      responseData = { sales: getSalesWithItems() };
    } else if (action === 'getJournal') {
      responseData = { journal: getSheetRecords('Jurnal_Keuangan').map(parseJournalRow) };
    } else if (action === 'fallbackAction' && params.payload) {
      // Fallback jika browser perangkat tertentu memblokir POST
      const parsed = JSON.parse(decodeURIComponent(params.payload));
      return handleAction(parsed, callback);
    } else {
      responseData = { status: 'unknown_action', action: action };
    }

    return createOutput({ status: 'success', data: responseData }, callback);
  } catch (err) {
    return createOutput({ status: 'error', message: err.toString() }, e && e.parameter && e.parameter.callback);
  }
}

/**
 * Handle POST Request (Menyimpan & Menghapus data transaksi, jurnal, dan harga)
 */
function doPost(e) {
  const lock = LockService.getScriptLock();
  // Kunci script maks 30 detik untuk menjamin urutan data saat banyak kasir/perangkat mengakses
  lock.tryLock(30000);

  try {
    initAllSheets();
    let payload = {};
    if (e && e.postData && e.postData.contents) {
      payload = JSON.parse(e.postData.contents);
    } else if (e && e.parameter && e.parameter.payload) {
      payload = JSON.parse(e.parameter.payload);
    }

    return handleAction(payload);
  } catch (err) {
    return createOutput({ status: 'error', message: err.toString() });
  } finally {
    lock.releaseLock();
  }
}

/**
 * Router untuk memproses berbagai action dari frontend
 */
function handleAction(payload, callback) {
  const action = payload.action;

  // 1. Simpan Transaksi Penjualan Baru (Checkout POS)
  if (action === 'saveSale') {
    const sale = payload.sale;
    const movements = payload.stockMovements || [];
    const journals = payload.journalEntries || [];
    const stockUpdates = payload.stockUpdates || [];

    if (!sale || !sale.invoiceNo) {
      return createOutput({ status: 'error', message: 'Data penjualan tidak lengkap' }, callback);
    }

    // A. Simpan ke sheet Transaksi
    const shTrx = SS.getSheetByName('Transaksi');
    const itemsJsonStr = JSON.stringify(sale.items || []);
    shTrx.appendRow([
      sale.id || ('sale_' + Date.now()),
      sale.invoiceNo,
      sale.date || new Date().toISOString(),
      sale.customerName || 'Pelanggan Umum',
      (sale.items || []).length,
      Number(sale.subtotal) || 0,
      Number(sale.discountAmount) || 0,
      Number(sale.total) || 0,
      Number(sale.totalHpp) || 0,
      (Number(sale.total) || 0) - (Number(sale.totalHpp) || 0),
      sale.paymentMethod || 'Tunai',
      sale.notes || '',
      itemsJsonStr
    ]);

    // B. Simpan rincian item ke sheet Transaksi_Item (mudah dibaca manusia di spreadsheet)
    if (sale.items && sale.items.length) {
      const shItem = SS.getSheetByName('Transaksi_Item');
      const itemRows = sale.items.map(it => [
        sale.invoiceNo,
        it.refId || '',
        it.nama || '',
        it.type || 'barang',
        Number(it.qty) || 0,
        Number(it.harga) || 0,
        Number(it.hppUnit) || 0,
        Number(it.subtotal) || ((Number(it.harga) || 0) * (Number(it.qty) || 0)),
        sale.date || new Date().toISOString()
      ]);
      shItem.getRange(shItem.getLastRow() + 1, 1, itemRows.length, itemRows[0].length).setValues(itemRows);
    }

    // C. Simpan Jurnal Keuangan
    if (journals.length) {
      const shJrn = SS.getSheetByName('Jurnal_Keuangan');
      const jrnRows = journals.map(j => [
        j.id || ('jrn_' + Date.now()),
        j.date || new Date().toISOString(),
        j.type || 'Penjualan',
        j.refNo || sale.invoiceNo,
        j.description || '',
        j.direction || 'in',
        Number(j.amount) || 0,
        Number(j.hpp) || 0,
        j.paymentMethod || sale.paymentMethod || 'Tunai',
        JSON.stringify(j.meta || {})
      ]);
      shJrn.getRange(shJrn.getLastRow() + 1, 1, jrnRows.length, jrnRows[0].length).setValues(jrnRows);
    }

    // D. Simpan Mutasi Stok
    if (movements.length) {
      const shMut = SS.getSheetByName('Mutasi_Stok');
      const mutRows = movements.map(m => [
        m.id || ('mov_' + Date.now()),
        m.date || new Date().toISOString(),
        m.type || 'out',
        m.source || 'penjualan_barang',
        m.productId || '',
        m.productName || '',
        Number(m.qty) || 0,
        Number(m.stockBefore) || 0,
        Number(m.stockAfter) || 0,
        m.refNo || sale.invoiceNo,
        m.notes || ''
      ]);
      shMut.getRange(shMut.getLastRow() + 1, 1, mutRows.length, mutRows[0].length).setValues(mutRows);
    }

    // E. Kurangi Stok Fisik di Tab 'Harga Dasar' jika ada
    if (stockUpdates && stockUpdates.length) {
      updateStockInHargaDasar(stockUpdates);
    }

    return createOutput({
      status: 'success',
      message: 'Transaksi ' + sale.invoiceNo + ' berhasil disimpan ke Google Sheets.',
      invoiceNo: sale.invoiceNo
    }, callback);
  }

  // 2. Simpan Catatan Pengeluaran Baru
  if (action === 'saveExpense') {
    const exp = payload.expense;
    if (!exp) return createOutput({ status: 'error', message: 'Data pengeluaran kosong' }, callback);

    const shJrn = SS.getSheetByName('Jurnal_Keuangan');
    shJrn.appendRow([
      exp.id || ('jrn_' + Date.now()),
      exp.date || new Date().toISOString(),
      exp.type || 'Pengeluaran',
      exp.refNo || ('EXP-' + Date.now().toString().slice(-5)),
      exp.description || '',
      'out',
      Number(exp.amount) || 0,
      0,
      exp.paymentMethod || 'Tunai',
      JSON.stringify(exp.meta || {})
    ]);

    return createOutput({ status: 'success', message: 'Pengeluaran berhasil dicatat ke Spreadsheet.' }, callback);
  }

  // 3. Hapus Transaksi Penjualan
  if (action === 'deleteSale') {
    const saleId = payload.saleId;
    const invoiceNo = payload.invoiceNo;
    const restoredStock = payload.restoredStock || [];

    if (!saleId && !invoiceNo) {
      return createOutput({ status: 'error', message: 'ID transaksi tidak diberikan' }, callback);
    }

    // Hapus dari Transaksi
    deleteRowByColumn('Transaksi', 1, saleId, invoiceNo);
    // Hapus dari Transaksi_Item
    if (invoiceNo) deleteRowsByColumn('Transaksi_Item', 0, invoiceNo);
    // Hapus dari Jurnal_Keuangan
    if (invoiceNo) deleteRowsByColumn('Jurnal_Keuangan', 3, invoiceNo);

    // Kembalikan stok di Harga Dasar jika diminta
    if (restoredStock.length) {
      updateStockInHargaDasar(restoredStock);
    }

    return createOutput({ status: 'success', message: 'Transaksi berhasil dihapus dari Spreadsheet.' }, callback);
  }

  // 4. Hapus Catatan Jurnal
  if (action === 'deleteJournal') {
    const id = payload.id;
    if (!id) return createOutput({ status: 'error', message: 'ID jurnal tidak diberikan' }, callback);
    deleteRowByColumn('Jurnal_Keuangan', 0, id);
    return createOutput({ status: 'success', message: 'Catatan jurnal berhasil dihapus dari Spreadsheet.' }, callback);
  }

  // 5. Simpan Harga Kustom / Pengaturan Katalog
  if (action === 'saveCustomPrices') {
    const prices = payload.customPrices || {};
    saveSettingRecord('customPrices', prices);
    return createOutput({ status: 'success', message: 'Harga kustom berhasil disimpan ke Spreadsheet.' }, callback);
  }

  // 6. Bulk Upload (Unggah Seluruh Data Lokal Kasir ke Spreadsheet)
  if (action === 'bulkUpload') {
    const sales = payload.sales || [];
    const journal = payload.journal || [];
    const stockMovements = payload.stockMovements || [];

    if (sales.length) {
      const shTrx = SS.getSheetByName('Transaksi');
      const shItem = SS.getSheetByName('Transaksi_Item');
      const trxRows = [];
      const itemRows = [];

      sales.forEach(sale => {
        trxRows.push([
          sale.id || ('sale_' + Date.now()),
          sale.invoiceNo,
          sale.date || new Date().toISOString(),
          sale.customerName || 'Pelanggan Umum',
          (sale.items || []).length,
          Number(sale.subtotal) || 0,
          Number(sale.discountAmount) || 0,
          Number(sale.total) || 0,
          Number(sale.totalHpp) || 0,
          (Number(sale.total) || 0) - (Number(sale.totalHpp) || 0),
          sale.paymentMethod || 'Tunai',
          sale.notes || '',
          JSON.stringify(sale.items || [])
        ]);

        (sale.items || []).forEach(it => {
          itemRows.push([
            sale.invoiceNo,
            it.refId || '',
            it.nama || '',
            it.type || 'barang',
            Number(it.qty) || 0,
            Number(it.harga) || 0,
            Number(it.hppUnit) || 0,
            Number(it.subtotal) || ((Number(it.harga) || 0) * (Number(it.qty) || 0)),
            sale.date || new Date().toISOString()
          ]);
        });
      });

      if (trxRows.length) shTrx.getRange(shTrx.getLastRow() + 1, 1, trxRows.length, trxRows[0].length).setValues(trxRows);
      if (itemRows.length) shItem.getRange(shItem.getLastRow() + 1, 1, itemRows.length, itemRows[0].length).setValues(itemRows);
    }

    if (journal.length) {
      const shJrn = SS.getSheetByName('Jurnal_Keuangan');
      const jrnRows = journal.map(j => [
        j.id || ('jrn_' + Date.now()),
        j.date || new Date().toISOString(),
        j.type || 'Jurnal',
        j.refNo || '-',
        j.description || '',
        j.direction || 'neutral',
        Number(j.amount) || 0,
        Number(j.hpp) || 0,
        j.paymentMethod || 'Tunai',
        JSON.stringify(j.meta || {})
      ]);
      if (jrnRows.length) shJrn.getRange(shJrn.getLastRow() + 1, 1, jrnRows.length, jrnRows[0].length).setValues(jrnRows);
    }

    return createOutput({
      status: 'success',
      message: `Berhasil mengunggah ${sales.length} transaksi dan ${journal.length} jurnal ke Spreadsheet.`
    }, callback);
  }

  return createOutput({ status: 'error', message: 'Action tidak dikenal: ' + action }, callback);
}

// -------------------------------------------------------------------------
// FUNGSI BANTU (HELPERS)
// -------------------------------------------------------------------------

function createOutput(obj, callback) {
  if (callback) {
    return ContentService.createTextOutput(callback + '(' + JSON.stringify(obj) + ');')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function initAllSheets() {
  Object.keys(HEADERS).forEach(name => {
    let sh = SS.getSheetByName(name);
    if (!sh) {
      sh = SS.insertSheet(name);
      sh.appendRow(HEADERS[name]);
      sh.getRange(1, 1, 1, HEADERS[name].length).setFontWeight('bold').setBackground('#E2E8F0');
      sh.setFrozenRows(1);
    }
  });
}

function getSheetRecords(sheetName) {
  const sh = SS.getSheetByName(sheetName);
  if (!sh) return [];
  const rows = sh.getDataRange().getValues();
  if (rows.length < 2) return [];
  const headers = rows[0];
  return rows.slice(1).map(r => {
    const obj = {};
    headers.forEach((h, idx) => { obj[h] = r[idx]; });
    return obj;
  });
}

function getSalesWithItems() {
  const shTrx = SS.getSheetByName('Transaksi');
  if (!shTrx) return [];
  const rows = shTrx.getDataRange().getValues();
  if (rows.length < 2) return [];
  const headers = rows[0];

  return rows.slice(1).map(r => {
    const rowObj = {};
    headers.forEach((h, idx) => { rowObj[h] = r[idx]; });

    let items = [];
    if (rowObj.itemsJson) {
      try { items = JSON.parse(rowObj.itemsJson); } catch (e) {}
    }

    return {
      id: String(rowObj.id || rowObj.invoiceNo),
      invoiceNo: String(rowObj.invoiceNo),
      date: String(rowObj.date),
      customerName: String(rowObj.customerName || 'Pelanggan Umum'),
      subtotal: Number(rowObj.subtotal) || 0,
      discountAmount: Number(rowObj.discountAmount) || 0,
      total: Number(rowObj.total) || 0,
      totalHpp: Number(rowObj.totalHpp) || 0,
      paymentMethod: String(rowObj.paymentMethod || 'Tunai'),
      notes: String(rowObj.notes || ''),
      items: items
    };
  }).reverse(); // Urutan terbaru di atas
}

function parseJournalRow(j) {
  let meta = {};
  if (j.metaJson) {
    try { meta = JSON.parse(j.metaJson); } catch (e) {}
  }
  return {
    id: String(j.id),
    date: String(j.date),
    type: String(j.type),
    refNo: String(j.refNo || '-'),
    description: String(j.description || ''),
    direction: String(j.direction || 'neutral'),
    amount: Number(j.amount) || 0,
    hpp: Number(j.hpp) || 0,
    paymentMethod: String(j.paymentMethod || 'Tunai'),
    meta: meta
  };
}

function updateStockInHargaDasar(updates) {
  const sh = SS.getSheetByName('Harga Dasar');
  if (!sh) return;
  const data = sh.getDataRange().getValues();
  if (data.length < 2) return;

  const updateMap = new Map();
  updates.forEach(u => {
    if (u.nama) updateMap.set(String(u.nama).toLowerCase().trim(), Number(u.stok));
    if (u.no) updateMap.set('no_' + u.no, Number(u.stok));
  });

  // Kolom A = No (idx 0), Kolom C = Nama (idx 2), Kolom E = Stok (idx 4)
  for (let i = 1; i < data.length; i++) {
    const rowNo = 'no_' + data[i][0];
    const rowName = String(data[i][2] || '').toLowerCase().trim();

    if (updateMap.has(rowName)) {
      sh.getRange(i + 1, 5).setValue(updateMap.get(rowName));
    } else if (updateMap.has(rowNo)) {
      sh.getRange(i + 1, 5).setValue(updateMap.get(rowNo));
    }
  }
}

function saveSettingRecord(key, val) {
  const sh = SS.getSheetByName('Pengaturan_Web');
  if (!sh) return;
  const data = sh.getDataRange().getValues();
  const now = new Date().toISOString();
  const valStr = typeof val === 'object' ? JSON.stringify(val) : String(val);

  for (let i = 1; i < data.length; i++) {
    if (String(data[i][0]) === key) {
      sh.getRange(i + 1, 2, 1, 2).setValues([[valStr, now]]);
      return;
    }
  }
  sh.appendRow([key, valStr, now]);
}

function getSettingRecord(key) {
  const sh = SS.getSheetByName('Pengaturan_Web');
  if (!sh) return null;
  const data = sh.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][0]) === key) {
      try {
        return JSON.parse(data[i][1]);
      } catch (e) {
        return data[i][1];
      }
    }
  }
  return null;
}

function deleteRowByColumn(sheetName, colIdx, targetVal, altVal) {
  const sh = SS.getSheetByName(sheetName);
  if (!sh) return;
  const data = sh.getDataRange().getValues();
  for (let i = data.length - 1; i >= 1; i--) {
    const cellVal = String(data[i][colIdx]);
    if (cellVal === String(targetVal) || (altVal && cellVal === String(altVal))) {
      sh.deleteRow(i + 1);
      return;
    }
  }
}

function deleteRowsByColumn(sheetName, colIdx, targetVal) {
  const sh = SS.getSheetByName(sheetName);
  if (!sh) return;
  const data = sh.getDataRange().getValues();
  for (let i = data.length - 1; i >= 1; i--) {
    const cellVal = String(data[i][colIdx]);
    if (cellVal === String(targetVal)) {
      sh.deleteRow(i + 1);
    }
  }
}
