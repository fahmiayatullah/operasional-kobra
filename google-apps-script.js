/**
 * =========================================================================
 * BACKEND API GOOGLE APPS SCRIPT — SISTEM OPERASIONAL PERCETAKAN KOBRA HITAM
 * =========================================================================
 * 
 * PANDUAN PEMASANGAN:
 * 1. Buka Google Spreadsheet baru di Google Drive Anda (misal: "Database Percetakan Kobra Hitam").
 * 2. Klik menu "Extensions" (Ekstensi) > "Apps Script".
 * 3. Hapus kode default, lalu salin dan tempel SELURUH KODE di bawah ini ke editor.
 * 4. Klik tombol "Save" (ikon disket).
 * 5. Klik tombol "Deploy" (Terapkan) di kanan atas > "New deployment" (Penerapan baru).
 * 6. Pilih jenis "Web app" (Aplikasi web).
 * 7. Isi:
 *    - Description: API Database Kobra Hitam
 *    - Execute as: Me (email Google Anda)
 *    - Who has access: Anyone (Siapa saja)  <-- PENTING agar web Anda bisa mengirim data
 * 8. Klik "Deploy", lalu izinkan hak akses (Authorize Access).
 * 9. Salin "Web App URL" yang diberikan, lalu masukkan URL tersebut ke menu Pengaturan di web Kobra Hitam!
 */

const SS = SpreadsheetApp.getActiveSpreadsheet();

// Header kolom standar untuk inisialisasi sheet otomatis
const HEADERS = {
  Barang: ['id', 'nama', 'tanggalPembelian', 'deskripsi', 'stok', 'isiKemasan', 'hargaBeli', 'hargaBeliSatuan', 'hargaJual', 'kategoriId', 'aktif'],
  Transaksi: ['invoiceNo', 'date', 'customerName', 'totalItems', 'subtotal', 'discountAmount', 'total', 'totalHpp', 'labaKotor', 'paymentMethod', 'notes'],
  Transaksi_Item: ['invoiceNo', 'itemId', 'nama', 'type', 'qty', 'harga', 'hppUnit', 'subtotal'],
  Mutasi_Stok: ['id', 'date', 'type', 'source', 'productId', 'productName', 'qty', 'stockBefore', 'stockAfter', 'refNo', 'notes'],
  Jurnal_Keuangan: ['id', 'date', 'type', 'refNo', 'description', 'direction', 'amount', 'paymentMethod']
};

/**
 * Handle GET Request (Mengambil data dari Google Sheets ke Web)
 */
function doGet(e) {
  try {
    const action = (e && e.parameter && e.parameter.action) || 'getAll';
    let responseData = {};

    initAllSheets();

    if (action === 'getAll') {
      responseData = {
        products: getSheetRecords('Barang'),
        sales: getSheetRecords('Transaksi'),
        stockMovements: getSheetRecords('Mutasi_Stok'),
        journal: getSheetRecords('Jurnal_Keuangan')
      };
    } else if (action === 'getProducts') {
      responseData = { products: getSheetRecords('Barang') };
    } else if (action === 'ping') {
      responseData = { pong: true, time: new Date().toISOString() };
    }

    return ContentService.createTextOutput(JSON.stringify({ status: 'success', data: responseData }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ status: 'error', message: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * Handle POST Request (Menyimpan data dari Web ke Google Sheets)
 */
function doPost(e) {
  const lock = LockService.getScriptLock();
  // Kunci script selama maks 30 detik untuk mencegah tabrakan data (race condition)
  lock.tryLock(30000);

  try {
    initAllSheets();
    const payload = JSON.parse(e.postData.contents);
    const action = payload.action;

    if (action === 'saveSale') {
      const sale = payload.sale;
      const updatedProducts = payload.updatedProducts || [];
      const movements = payload.stockMovements || [];
      const journals = payload.journalEntries || [];

      // 1. Simpan Transaksi Header
      const shTrx = SS.getSheetByName('Transaksi');
      shTrx.appendRow([
        sale.invoiceNo, sale.date, sale.customerName,
        (sale.items || []).length, sale.subtotal, sale.discountAmount || 0,
        sale.total, sale.totalHpp || 0, (sale.total || 0) - (sale.totalHpp || 0),
        sale.paymentMethod, sale.notes || ''
      ]);

      // 2. Simpan Rincian Item Penjualan
      if (sale.items && sale.items.length) {
        const shItem = SS.getSheetByName('Transaksi_Item');
        const itemRows = sale.items.map(it => [
          sale.invoiceNo, it.refId, it.nama, it.type,
          it.qty, it.harga, it.hppUnit || 0, it.subtotal || (it.harga * it.qty)
        ]);
        shItem.getRange(shItem.getLastRow() + 1, 1, itemRows.length, itemRows[0].length).setValues(itemRows);
      }

      // 3. Update Stok di Sheet Barang
      if (updatedProducts.length) {
        updateStockInSheet(updatedProducts);
      }

      // 4. Catat Mutasi Stok
      if (movements.length) {
        const shMut = SS.getSheetByName('Mutasi_Stok');
        const mutRows = movements.map(m => [
          m.id, m.date, m.type, m.source, m.productId,
          m.productName, m.qty, m.stockBefore, m.stockAfter, m.refNo || sale.invoiceNo, m.notes || ''
        ]);
        shMut.getRange(shMut.getLastRow() + 1, 1, mutRows.length, mutRows[0].length).setValues(mutRows);
      }

      // 5. Catat Jurnal Keuangan
      if (journals.length) {
        const shJrn = SS.getSheetByName('Jurnal_Keuangan');
        const jrnRows = journals.map(j => [
          j.id, j.date, j.type, j.refNo || sale.invoiceNo, j.description,
          j.direction, j.amount, j.paymentMethod || sale.paymentMethod
        ]);
        shJrn.getRange(shJrn.getLastRow() + 1, 1, jrnRows.length, jrnRows[0].length).setValues(jrnRows);
      }

      return ContentService.createTextOutput(JSON.stringify({ status: 'success', message: 'Transaksi berhasil disimpan ke Spreadsheet.' }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    if (action === 'syncAllProducts') {
      // Sinkronkan seluruh master barang (83 item) ke sheet
      const products = payload.products || [];
      const shPrd = SS.getSheetByName('Barang');
      shPrd.clearContents();
      shPrd.appendRow(HEADERS.Barang);

      if (products.length) {
        const rows = products.map(p => [
          p.id, p.nama, p.tanggalPembelian || '', p.deskripsi || '',
          Number(p.stok) || 0, p.isiKemasan || '', Number(p.hargaBeli) || 0,
          Number(p.hargaBeliSatuan) || 0, Number(p.hargaJual) || 0,
          p.kategoriId || '', p.aktif !== false
        ]);
        shPrd.getRange(2, 1, rows.length, rows[0].length).setValues(rows);
      }

      return ContentService.createTextOutput(JSON.stringify({ status: 'success', message: `Berhasil sinkronkan ${products.length} barang ke Spreadsheet.` }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    return ContentService.createTextOutput(JSON.stringify({ status: 'error', message: 'Action tidak dikenal' }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ status: 'error', message: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  } finally {
    lock.releaseLock();
  }
}

// ----------------- FUNGSI BANTU (HELPERS) -----------------

function initAllSheets() {
  Object.keys(HEADERS).forEach(name => {
    let sh = SS.getSheetByName(name);
    if (!sh) {
      sh = SS.insertSheet(name);
      sh.appendRow(HEADERS[name]);
      sh.getRange(1, 1, 1, HEADERS[name].length).setFontWeight('bold').setBackground('#F1F5F9');
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

function updateStockInSheet(updatedProducts) {
  const sh = SS.getSheetByName('Barang');
  if (!sh) return;
  const values = sh.getDataRange().getValues();
  if (values.length < 2) return;

  const idColIdx = 0; // Kolom id
  const stokColIdx = 4; // Kolom stok
  const stockMap = new Map();
  updatedProducts.forEach(p => stockMap.set(String(p.id), Number(p.stok)));

  for (let i = 1; i < values.length; i++) {
    const id = String(values[i][idColIdx]);
    if (stockMap.has(id)) {
      sh.getRange(i + 1, stokColIdx + 1).setValue(stockMap.get(id));
    }
  }
}
