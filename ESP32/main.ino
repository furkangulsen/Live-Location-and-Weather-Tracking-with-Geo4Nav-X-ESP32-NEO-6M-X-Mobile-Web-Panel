#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <TinyGPS++.h>
#include "javascript_content.h"

const char* ssid = "WIFI_SSID";
const char* password = "WIFI_PASSWORD";

// Thingspeak API
const char* apiKey = "apiKey";  // Yazma API Key
const char* readAPIKey = "readAPIKey";
const char* channelID = "channelID";
const char* locationIQApiKey = "pk.locationIQApiKey"; // LocationIQ API Key

// Footer ve başlık bilgisi için global değişkenler
const char* footerText = "© 2025 Geo4Nav";
const char* titleText = "Geo4Nav Web Panel";

WebServer server(80); 

TinyGPSPlus gps;

String gpsStatusMessage = "GPS bekleniyor...";
String lastGpsLocation = "Enlem: N/A, Boylam: N/A";
String lastGpsDataFull = "";
String lastRawGPRMC = "N/A"; // Ham GPRMC verisi için yeni global değişken

unsigned long lastGpsSendTime = 0; // Son GPS veri gönderme zamanı
const long GPS_SEND_INTERVAL_MS = 5000; // Her 5 saniyede bir gönder

// HTML için global değişkenler
String channelInfoHtml = "";
String feedsTableHtml = "";

// Helper to pad strings (sağdan boşluk doldurma)
String padRight(String str, int len) {
  while (str.length() < len) {
    str += " ";
  }
  return str;
}

// Tüm feed başlıklarını (etiketlerini) bulur
void extractFeedHeaders(String feedsJson, String* headers, int& headerCount) {
  headerCount = 0;
  int firstObjStart = feedsJson.indexOf('{');
  int firstObjEnd = feedsJson.indexOf('}', firstObjStart);
  if (firstObjStart == -1 || firstObjEnd == -1) return;
  String firstFeed = feedsJson.substring(firstObjStart + 1, firstObjEnd);
  int pos = 0;
  while (true) {
    int keyStart = firstFeed.indexOf('"', pos);
    if (keyStart == -1) break;
    int keyEnd = firstFeed.indexOf('"', keyStart + 1);
    String key = firstFeed.substring(keyStart + 1, keyEnd);
    headers[headerCount++] = key;
    pos = firstFeed.indexOf(':', keyEnd) + 1;
    int nextComma = firstFeed.indexOf(',', pos);
    if (nextComma == -1) break;
    pos = nextComma + 1;
    if (headerCount >= 10) break; // Güvenlik için
  }
}

// Thingspeak'ten verileri çekip HTML tabloya döker (SON 100 veri, EN YENİ EN ÜSTTE)
bool fetchAndBuildTables() {
  HTTPClient http;
  // Sadece son 100 veri çekiyoruz!
  String url = "https://api.thingspeak.com/channels/channelID/feeds.json?api_key=API_KEY&results=100";
  http.begin(url);
  int httpCode = http.GET();
  if (httpCode != 200) {
    http.end();
    channelInfoHtml = "<div class='alert' style='color:#dc3545;'>Veri alınamadı!</div>";
    feedsTableHtml = "";
    return false;
  }
  String payload = http.getString();
  http.end();

  // Channel bilgileri
  int chStart = payload.indexOf("\"channel\":{");
  int chEnd = payload.indexOf("},\"feeds\":[");
  if (chStart == -1 || chEnd == -1) {
    channelInfoHtml = "<div class='alert' style='color:#dc3545;'>Kanal bilgisi bulunamadı!</div>";
    feedsTableHtml = "";
    return false;
  }
  String channelJson = payload.substring(chStart + 11, chEnd + 1);
  channelInfoHtml = "<div class='channel-info'><h3>Kanal Bilgileri</h3><table>";
  int pos = 0;
  while (true) {
    int keyStart = channelJson.indexOf('"', pos);
    if (keyStart == -1) break;
    int keyEnd = channelJson.indexOf('"', keyStart + 1);
    String key = channelJson.substring(keyStart + 1, keyEnd);
    int valStart = channelJson.indexOf(':', keyEnd) + 1;
    char valChar = channelJson[valStart];
    String value = "";
    if (valChar == '"') {
      int valEnd = channelJson.indexOf('"', valStart + 1);
      value = channelJson.substring(valStart + 1, valEnd);
      pos = valEnd + 1;
    } else {
      int valEnd = channelJson.indexOf(',', valStart);
      if (valEnd == -1) valEnd = channelJson.indexOf('}', valStart);
      value = channelJson.substring(valStart, valEnd);
      value.trim();
      pos = valEnd + 1;
    }
    channelInfoHtml += "<tr><td>" + key + "</td><td>" + value + "</td></tr>";
  }
  channelInfoHtml += "</table></div>";

  // Feeds tablosu (SON 100 veri, EN YENİ EN ÜSTTE)
  int feedsStart = payload.indexOf("\"feeds\":[");
  int feedsEnd = payload.lastIndexOf("]}");
  if (feedsStart == -1 || feedsEnd == -1) {
    feedsTableHtml = "<div class='alert' style='color:#dc3545;'>Veri bulunamadı!</div>";
    return false;
  }
  String feedsJson = payload.substring(feedsStart + 8, feedsEnd + 1);

  // Headerları bul
  String headers[10];
  int headerCount = 0;
  extractFeedHeaders(feedsJson, headers, headerCount);

  // Her feed objesinin başlangıç ve bitiş indekslerini bul
  int feedCount = 0;
  int objStarts[100];
  int objEnds[100];
  int searchPos = 0;
  while (true) {
    int objStart = feedsJson.indexOf('{', searchPos);
    int objEnd = feedsJson.indexOf('}', objStart);
    if (objStart == -1 || objEnd == -1) break;
    objStarts[feedCount] = objStart;
    objEnds[feedCount] = objEnd;
    feedCount++;
    searchPos = objEnd + 1;
    if (searchPos >= feedsJson.length()) break;
    if (feedCount >= 100) break; // Sadece 100 veri!
  }

  // Tablo başlıkları
  feedsTableHtml = "<div class='feeds-table'><h3>Son 100 Veri (En Yeni En Üstte)</h3><table><tr><th>#</th>";
  for (int i = 0; i < headerCount; i++) {
    String headerName = headers[i];
    if (headerName == "field1") {
      feedsTableHtml += "<th>Enlem</th>";
    } else if (headerName == "field2") {
      feedsTableHtml += "<th>Boylam</th>";
    } else {
      feedsTableHtml += "<th>" + headerName + "</th>";
    }
  }
  feedsTableHtml += "</tr>";

  // Satırları sondan başa (en yeni en üstte) işle
  int row = 1;
  for (int i = feedCount - 1; i >= 0; i--) {
    String obj = feedsJson.substring(objStarts[i] + 1, objEnds[i]);
    feedsTableHtml += "<tr";
    if (row == 1) feedsTableHtml += " style='background:#fffbe6;font-weight:bold;'";
    feedsTableHtml += "><td>" + String(row) + "</td>";
    for (int j = 0; j < headerCount; j++) {
      String key = "\"" + headers[j] + "\":";
      int kpos = obj.indexOf(key);
      String value = "-";
      if (kpos != -1) {
        int vpos = kpos + key.length();
        if (obj[vpos] == '"') {
          int vend = obj.indexOf('"', vpos + 1);
          value = obj.substring(vpos + 1, vend);
        } else {
          int vend = obj.indexOf(",", vpos);
          if (vend == -1) vend = obj.length();
          value = obj.substring(vpos, vend);
          value.trim();
        }
      }
      feedsTableHtml += "<td>" + value + "</td>";
    }
    feedsTableHtml += "</tr>";
    row++;
  }
  feedsTableHtml += "</table></div>";
  return true;
}

// Modern ana sayfa
String generateHomePage() {
  String html = R"rawliteral(
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Ana Sayfa</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background: linear-gradient(135deg, #e0e7ef 0%, #f8fafc 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        margin: 0;
        padding: 20px;
      }
      .container {
        background: white;
        padding: 40px 40px 50px 40px;
        border-radius: 18px;
        box-shadow: 0 10px 32px rgba(0,0,0,0.13);
        max-width: 420px;
        width: 100%;
        box-sizing: border-box;
        margin: 30px 0;
        text-align: center;
      }
      h1 {
        color: #2f72bc;
        margin-bottom: 30px;
        font-weight: 700;
        font-size: 2.1rem;
        letter-spacing: 0.5px;
      }
      .main-btn {
        display: block;
        width: 100%;
        margin: 18px 0;
        padding: 22px 0;
        font-size: 1.3rem;
        font-weight: 700;
        color: white;
        background: linear-gradient(90deg, #2f72bc 0%, #4fa3e3 100%);
        border: none;
        border-radius: 14px;
        box-shadow: 0 2px 8px #2f72bc22;
        cursor: pointer;
        transition: background 0.3s, box-shadow 0.2s, transform 0.1s;
        text-decoration: none;
      }
      .main-btn:hover {
        background: linear-gradient(90deg, #1d4f8c 0%, #2f72bc 100%);
        box-shadow: 0 5px 15px rgba(29, 79, 140, 0.13);
        transform: scale(1.03);
      }
      footer {
        margin-top: 35px;
        font-size: 14px;
        color: #777;
        text-align: center;
        user-select: none;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>)rawliteral" + String(titleText) + R"rawliteral(</h1>
      <a href="/veri_gonder" class="main-btn">Veri Gönder</a>
      <a href="/verileri_listele" class="main-btn">Verileri Listele</a>
      <a href="/gps_verileri" class="main-btn">GPS Verileri</a>
      <a href="/reverse_geocode" class="main-btn">Tam Konum (Reverse Geocoding)</a>
      <a href="/haritada_goster" class="main-btn">Tam Konum (Haritada)</a>
      <a href="/hava_durumu" class="main-btn">Hava Durumu</a>
      <footer>)rawliteral" + String(footerText) + R"rawliteral(</footer>
    </div>
  </body>
  </html>
  )rawliteral";
  return html;
}

// Veri gönderme sayfası
String generateSendPage(String message = "", bool success = false) {
  String color = success ? "#28a745" : "#dc3545";
  String alert = message.length() > 0 ?
    "<div class=\"alert\" style=\"color:" + color + ";\">" + message + "</div>" : "";
  String html = R"rawliteral(
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Veri Gönder</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background: linear-gradient(135deg, #e0e7ef 0%, #f8fafc 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        margin: 0;
        padding: 20px;
      }
      .container {
        background: white;
        padding: 40px 40px 50px 40px;
        border-radius: 18px;
        box-shadow: 0 10px 32px rgba(0,0,0,0.13);
        max-width: 420px;
        width: 100%;
        box-sizing: border-box;
        margin: 30px 0;
      }
      h1 {
        text-align: center;
        color: #2f72bc;
        margin-bottom: 30px;
        font-weight: 700;
        font-size: 2.1rem;
        letter-spacing: 0.5px;
      }
      .alert {
        text-align: center;
        font-weight: 600;
        margin-bottom: 25px;
        user-select: none;
        font-size: 1.1rem;
      }
      form {
        display: grid;
        grid-template-columns: 1fr;
        gap: 18px;
        margin-top: 18px;
      }
      label {
        font-weight: 600;
        color: #444;
        margin-bottom: 6px;
        display: block;
        font-size: 1rem;
      }
      input[type=number] {
        width: 100%;
        padding: 14px 16px;
        font-size: 1rem;
        border: 2px solid #ddd;
        border-radius: 10px;
        box-sizing: border-box;
        transition: border-color 0.3s ease, box-shadow 0.3s ease;
        font-weight: 500;
        background: #f7fafc;
      }
      input[type=number]:focus {
        border-color: #2f72bc;
        box-shadow: 0 0 6px #2f72bcaa;
        outline: none;
      }
      button {
        padding: 15px 0;
        background: linear-gradient(90deg, #2f72bc 0%, #4fa3e3 100%);
        border: none;
        border-radius: 12px;
        color: white;
        font-size: 1.2rem;
        font-weight: 700;
        cursor: pointer;
        transition: background 0.3s, box-shadow 0.2s;
        width: 100%;
        box-shadow: 0 2px 8px #2f72bc22;
      }
      button:hover {
        background: linear-gradient(90deg, #1d4f8c 0%, #2f72bc 100%);
        box-shadow: 0 5px 15px rgba(29, 79, 140, 0.13);
      }
      button:active {
        transform: scale(0.98);
      }
      .back-btn {
        display: block;
        margin: 18px auto 0 auto;
        width: 100%;
        padding: 12px 0;
        font-size: 1.1rem;
        font-weight: 600;
        color: #2f72bc;
        background: #e9f5fe;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        text-decoration: none;
        transition: background 0.2s;
        text-align: center;
      }
      .back-btn:hover {
        background: #d0e7fa;
      }
      footer {
        margin-top: 35px;
        font-size: 14px;
        color: #777;
        text-align: center;
        user-select: none;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>)rawliteral" + String(titleText) + R"rawliteral(</h1>
      )rawliteral" + alert + R"rawliteral(
      <form action="/veri_gonder" method="GET" autocomplete="off">
        <label for="field1">Enlem:</label>
        <input type="number" id="field1" name="field1" step="any" placeholder="Enlem değerini gir" required />
        <label for="field2">Boylam:</label>
        <input type="number" id="field2" name="field2" step="any" placeholder="Boylam değerini gir" required />
        <button type="submit">Gönder</button>
      </form>
      <a href="/anasayfa" class="back-btn">← Ana Sayfa</a>
      <footer>)rawliteral" + String(footerText) + R"rawliteral(</footer>
    </div>
  </body>
  </html>
  )rawliteral";
  return html;
}

// Verileri listele sayfası
String generateListPage() {
  String html = R"rawliteral(
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Verileri Listele</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background: linear-gradient(135deg, #e0e7ef 0%, #f8fafc 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        margin: 0;
        padding: 20px;
      }
      .container {
        background: white;
        padding: 40px 40px 50px 40px;
        border-radius: 18px;
        box-shadow: 0 10px 32px rgba(0,0,0,0.13);
        max-width: 900px;
        width: 100%;
        box-sizing: border-box;
        margin: 30px 0;
      }
      h1 {
        text-align: center;
        color: #2f72bc;
        margin-bottom: 30px;
        font-weight: 700;
        font-size: 2.1rem;
        letter-spacing: 0.5px;
      }
      .channel-info, .feeds-table {
        margin-top: 25px;
        padding: 15px 20px;
        background: #f3f8fd;
        border-radius: 10px;
        color: #0b3e75;
        font-weight: 600;
        font-size: 1.08rem;
        text-align: center;
        user-select: text;
        overflow-x: auto;
        box-shadow: 0 2px 8px #2f72bc11;
      }
      table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 10px;
      }
      th, td {
        border: 1px solid #c7e0f7;
        padding: 8px 6px;
        font-size: 0.98rem;
      }
      th {
        background: #2f72bc;
        color: white;
        font-weight: 700;
        position: sticky;
        top: 0;
        z-index: 1;
      }
      tr:nth-child(even) {
        background: #e9f5fe;
      }
      tr:hover {
        background: #d0e7fa;
      }
      .back-btn {
        display: block;
        margin: 18px auto 0 auto;
        width: 100%;
        padding: 12px 0;
        font-size: 1.1rem;
        font-weight: 600;
        color: #2f72bc;
        background: #e9f5fe;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        text-decoration: none;
        transition: background 0.2s;
        text-align: center;
      }
      .back-btn:hover {
        background: #d0e7fa;
      }
      footer {
        margin-top: 35px;
        font-size: 14px;
        color: #777;
        text-align: center;
        user-select: none;
      }
      @media (max-width: 1000px) {
        .container {
          padding: 22px 4px 30px 4px;
        }
        .channel-info, .feeds-table {
          padding: 10px 2px;
        }
        th, td {
          font-size: 0.93rem;
        }
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>)rawliteral" + String(titleText) + R"rawliteral(</h1>
      )rawliteral" + channelInfoHtml + feedsTableHtml + R"rawliteral(
      <a href="/anasayfa" class="back-btn">← Ana Sayfa</a>
      <a href="/export_list_data" class="back-btn" style="margin-top: 10px;">Verileri Dışa Aktar (TXT)</a>
      <footer>)rawliteral" + String(footerText) + R"rawliteral(</footer>
    </div>
  </body>
  </html>
  )rawliteral";
  return html;
}

// GPS verileri sayfası
String generateGpsPage() {
  String html = R"rawliteral(
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>GPS Verileri</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background: linear-gradient(135deg, #e0e7ef 0%, #f8fafc 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        margin: 0;
        padding: 20px;
      }
      .container {
        background: white;
        padding: 40px 40px 50px 40px;
        border-radius: 18px;
        box-shadow: 0 10px 32px rgba(0,0,0,0.13);
        max-width: 500px;
        width: 100%;
        box-sizing: border-box;
        margin: 30px 0;
        text-align: center;
      }
      h1 {
        color: #2f72bc;
        margin-bottom: 30px;
        font-weight: 700;
        font-size: 2.1rem;
        letter-spacing: 0.5px;
      }
      .gps-info {
        margin-top: 25px;
        padding: 15px 20px;
        background: #f3f8fd;
        border-radius: 10px;
        color: #0b3e75;
        font-weight: 600;
        font-size: 1.08rem;
        text-align: left;
        user-select: text;
        box-shadow: 0 2px 8px #2f72bc11;
      }
      .gps-info p {
        margin: 8px 0;
        line-height: 1.5;
        word-wrap: break-word;
      }
      .gps-info strong {
        color: #2f72bc;
      }
      .button-container {
        display: flex;
        justify-content: center; /* Butonun yatayda ortalanması için */
        margin-top: 20px; /* Üst boşluk ekle */
      }
      .gps-copy-all-btn {
        background: #2f72bc;
        color: white;
        border: none;
        border-radius: 8px;
        padding: 12px 20px;
        font-size: 1rem;
        font-weight: 600;
        cursor: pointer;
        transition: background 0.3s, box-shadow 0.2s;
        box-shadow: 0 2px 8px #2f72bc22;
      }
      .gps-copy-all-btn:hover {
        background: #1d4f8c;
        box-shadow: 0 4px 12px rgba(29, 79, 140, 0.13);
      }
      .gps-copy-all-btn:active {
        transform: scale(0.98);
      }
      .back-btn {
        display: block;
        margin: 18px auto 0 auto;
        width: 100%;
        padding: 12px 0;
        font-size: 1.1rem;
        font-weight: 600;
        color: #2f72bc;
        background: #e9f5fe;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        text-decoration: none;
        transition: background 0.2s;
        text-align: center;
      }
      .back-btn:hover {
        background: #d0e7fa;
      }
      footer {
        margin-top: 35px;
        font-size: 14px;
        color: #777;
        text-align: center;
        user-select: none;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>)rawliteral" + String(titleText) + R"rawliteral(</h1>
      <div class="gps-info">
        <p><strong>Durum:</strong> <span id="gpsStatus" style="font-weight: bold;">Yükleniyor...</span></p>
        <p><strong>Konum:</strong> <span id="gpsLocation" data-latitude="N/A" data-longitude="N/A">Yükleniyor...</span></p>
        <p><strong>Son Tam Veri:</strong> <span id="gpsDataFull">Yükleniyor...</span></p>
        <p><strong>Ham GPRMC:</strong> <span id="rawGPRMC">Yükleniyor...</span></p>
        <div class="button-container">
          <button class="gps-copy-all-btn" id="copyAllGpsData">Tümünü Kopyala</button>
        </div>
      </div>
      <a href="/anasayfa" class="back-btn">← Ana Sayfa</a>
      <footer>)rawliteral" + String(footerText) + R"rawliteral(</footer>
    </div>
    <script>
      function fetchGpsData() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
          if (this.readyState == 4 && this.status == 200) {
            var data = JSON.parse(this.responseText);
            document.getElementById('gpsStatus').innerText = data.status;
            document.getElementById('gpsLocation').innerText = data.location;
            document.getElementById('gpsDataFull').innerText = data.full_data;
            document.getElementById('rawGPRMC').innerText = data.raw_gprmc;

            document.getElementById('gpsLocation').setAttribute('data-latitude', data.latitude);
            document.getElementById('gpsLocation').setAttribute('data-longitude', data.longitude);

            var gpsStatusElement = document.getElementById('gpsStatus');
            if (data.status.includes('Aktif')) {
              gpsStatusElement.style.color = '#28a745'; // Yeşil
            } else {
              gpsStatusElement.style.color = '#dc3545'; // Kırmızı
            }
          }
        };
        xhr.open("GET", "/get_gps_data", true);
        xhr.send();
      }
      setInterval(fetchGpsData, 2000); // Her 2 saniyede bir güncelle
      fetchGpsData(); // Sayfa yüklendiğinde ilk veriyi hemen çek

      // Tümünü Kopyala butonu için olay dinleyici ekle
      document.addEventListener('DOMContentLoaded', function() {
        document.getElementById('copyAllGpsData').addEventListener('click', function() {
          var status = document.getElementById('gpsStatus').innerText;
          var location = document.getElementById('gpsLocation').innerText;
          var fullData = document.getElementById('gpsDataFull').innerText;
          var rawGPRMC = document.getElementById('rawGPRMC').innerText;

          var combinedText = 
            "Durum: " + status + "\n" +
            "Konum: " + location + "\n" +
            "Son Tam Veri: " + fullData + "\n" +
            "Ham GPRMC: " + rawGPRMC;

          // panoya kopyalama için özel bir yardımcı fonksiyon kullan
          copyToClipboardInternal(combinedText);
        });
      });

      // Dahili kopyalama fonksiyonu
      function copyToClipboardInternal(text) {
        if (!navigator.clipboard) {
          // Clipboard API desteklenmiyorsa (eski tarayıcılar veya güvensiz bağlam)
          fallbackCopyTextToClipboard(text);
          return;
        }
        navigator.clipboard.writeText(text).then(function() {
        }, function(err) {
          console.error('Kopyalama başarısız: ', err);
        });
      }

      // Clipboard API desteklenmediğinde geri dönüş fonksiyonu
      function fallbackCopyTextToClipboard(text) {
        var textArea = document.createElement("textarea");
        textArea.value = text;
        
        // Ekran dışına taşıyarak kullanıcıya görünmemesini sağla
        textArea.style.position = "fixed";
        textArea.style.top = "-99999px";
        textArea.style.left = "-99999px";
        textArea.style.width = "1em";
        textArea.style.height = "1em";
        textArea.style.padding = "0";
        textArea.style.border = "none";
        textArea.style.outline = "none";
        textArea.style.boxShadow = "none";
        textArea.style.background = "transparent";

        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();

        try {
          var successful = document.execCommand('copy');
        } catch (err) {
          console.error('Fallback kopyalama başarısız: ', err);
        }

        document.body.removeChild(textArea);
      }
    </script>
  </body>
  </html>
  )rawliteral";
  return html;
}

// Harita sayfası
String generateMapsPage() {
  String html = "";
  html += "<!DOCTYPE html>\n";
  html += "<html lang=\"tr\">\n";
  html += "<head>\n";
  html += "  <title>Haritada Konum</title>\n";
  html += "  <meta charset=\"utf-8\" />\n";
  html += "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n";
  html += "\n";
  html += "  <link rel=\"stylesheet\" href=\"https://unpkg.com/leaflet@1.9.3/dist/leaflet.css\" />\n";
  html += "  <script src=\"https://unpkg.com/leaflet@1.9.3/dist/leaflet.js\"></script>\n";
  html += "\n";
  html += "  <style>\n";
  html += "    body {\n";
  html += "      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;\n";
  html += "      background: linear-gradient(135deg, #e0e7ef 0%, #f8fafc 100%);\n";
  html += "      display: flex;\n";
  html += "      flex-direction: column;\n";
  html += "      justify-content: center;\n";
  html += "      align-items: center;\n";
  html += "      min-height: 100vh;\n";
  html += "      margin: 0;\n";
  html += "      padding: 20px;\n";
  html += "    }\n";
  html += "    .container {\n";
  html += "      background: white;\n";
  html += "      padding: 30px 30px 40px 30px;\n";
  html += "      border-radius: 18px;\n";
  html += "      box-shadow: 0 10px 32px rgba(0,0,0,0.13);\n";
  html += "      max-width: 900px;\n";
  html += "      width: 100%;\n";
  html += "      box-sizing: border-box;\n";
  html += "      margin: 30px 0;\n";
  html += "      text-align: center;\n";
  html += "    }\n";
  html += "    h1 {\n";
  html += "      color: #2f72bc;\n";
  html += "      margin-bottom: 25px;\n";
  html += "      font-weight: 700;\n";
  html += "      font-size: 2.1rem;\n";
  html += "      letter-spacing: 0.5px;\n";
  html += "    }\n";
  html += "    #map {\n";
  html += "      height: 500px; /* Harita yüksekliğini artırdık */\n";
  html += "      width: 100%;\n";
  html += "      border-radius: 10px;\n";
  html += "      border: 2px solid #ddd;\n";
  html += "      box-shadow: 0 2px 8px rgba(0,0,0,0.1);\n";
  html += "    }\n";
  html += "    .back-btn {\n";
  html += "      display: block;\n";
  html += "      margin: 25px auto 0 auto;\n";
  html += "      width: 100%;\n";
  html += "      max-width: 300px;\n";
  html += "      padding: 12px 0;\n";
  html += "      font-size: 1.1rem;\n";
  html += "      font-weight: 600;\n";
  html += "      color: #2f72bc;\n";
  html += "      background: #e9f5fe;\n";
  html += "      border: none;\n";
  html += "      border-radius: 10px;\n";
  html += "      cursor: pointer;\n";
  html += "      text-decoration: none;\n";
  html += "      transition: background 0.2s;\n";
  html += "      text-align: center;\n";
  html += "    }\n";
  html += "    .back-btn:hover {\n";
  html += "      background: #d0e7fa;\n";
  html += "    }\n";
  html += "    footer {\n";
  html += "      margin-top: 35px;\n";
  html += "      font-size: 14px;\n";
  html += "      color: #777;\n";
  html += "      text-align: center;\n";
  html += "      user-select: none;\n";
  html += "    }\n";
  html += "    .current-coords {\n";
  html += "      margin-top: 15px;\n";
  html += "      font-size: 1.1rem;\n";
  html += "      font-weight: 600;\n";
  html += "      color: #0b3e75;\n";
  html += "    }\n";
  html += "  </style>\n";
  html += "</head>\n";
  html += "<body>\n";
  html += "  <div class=\"container\">\n";
  html += "    <h1>" + String(titleText) + "</h1>\n";
  html += "    <div id=\"map\"></div>\n";
  html += "    <p class=\"current-coords\">Güncel Konum: <span id=\"currentLat\">N/A</span>, <span id=\"currentLon\">N/A</span></p>\n";
  html += "    <a href=\"/anasayfa\" class=\"back-btn\">← Ana Sayfa</a>\n";
  html += "    <footer>" + String(footerText) + "</footer>\n";
  html += "  </div>\n";
  html += "  <script>\n";
  html += replaceSubstring(javascript_map_script, "\r", ""); // JavaScript kodunu ayrı dosyadan al, \r karakterlerini temizle
  html += "  </script>\n";
  html += "</body>\n";
  html += "</html>\n";
  return html;
}

// String içindeki bir alt dizgiyi başka bir alt dizgiyle değiştirir (String::insert yerine substring ve + kullanır)
String replaceSubstring(String original, String find, String replace) {
  String result = "";
  int lastIndex = 0;
  int foundIdx = original.indexOf(find);

  while (foundIdx != -1) {
    result += original.substring(lastIndex, foundIdx);
    result += replace;
    lastIndex = foundIdx + find.length();
    foundIdx = original.indexOf(find, lastIndex);
  }
  result += original.substring(lastIndex);
  return result;
}

// LocationIQ API'den gelen JSON'ı ayrıştırıp HTML'e dönüştürür
String parseLocationIQJson(String jsonPayload) {
  String htmlOutput = "";
  String displayName = "";

  // displayName'ı bul ve Unicode karakterleri düzelt
  int dnStart = jsonPayload.indexOf("\"display_name\":\"");
  if (dnStart != -1) {
    dnStart += String("\"display_name\":\"").length();
    int dnEnd = jsonPayload.indexOf("\"", dnStart);
    if (dnEnd != -1) {
      displayName = jsonPayload.substring(dnStart, dnEnd);
      // Unicode karakterleri düzelt
      displayName = replaceSubstring(displayName, "\\u00fc", "ü");
      displayName = replaceSubstring(displayName, "\\u00e7", "ç");
      displayName = replaceSubstring(displayName, "\\u011f", "ğ");
      displayName = replaceSubstring(displayName, "\\u0131", "ı");
      displayName = replaceSubstring(displayName, "\\u00f6", "ö");
      displayName = replaceSubstring(displayName, "\\u015f", "ş");
      displayName = replaceSubstring(displayName, "\\u00c7", "Ç");
      displayName = replaceSubstring(displayName, "\\u011e", "Ğ");
      displayName = replaceSubstring(displayName, "\\u0130", "İ");
      displayName = replaceSubstring(displayName, "\\u00d6", "Ö");
      displayName = replaceSubstring(displayName, "\\u015e", "Ş");
      displayName = replaceSubstring(displayName, "\\u00dc", "Ü");
    }
  }

  String addressHtml = "";
  // address objesini bul
  int addrStart = jsonPayload.indexOf("\"address\":{");
  if (addrStart != -1) {
    addrStart += String("\"address\":{").length();
    int addrEnd = jsonPayload.indexOf("}", addrStart);
    if (addrEnd != -1) {
      String addressJson = jsonPayload.substring(addrStart, addrEnd);
      
      // Belirli adres alanlarını arayarak HTML'e ekle
      String fields[][2] = {
        {"road", "Cadde/Sokak"},
        {"house_number", "Bina No"},
        {"suburb", "Semt"},
        {"city_district", "İlçe"},
        {"city", "Şehir"},
        {"province", "İl"}, // LocationIQ often returns 'state' as province for Turkey
        {"state", "Eyalet"},
        {"postcode", "Posta Kodu"},
        {"country", "Ülke"},
        {"country_code", "Ülke Kodu"}
      };

      for (int i = 0; i < sizeof(fields) / sizeof(fields[0]); i++) {
        String key = fields[i][0];
        String label = fields[i][1];
        String searchKey = "\"" + key + "\":";
        int kpos = addressJson.indexOf(searchKey);
        if (kpos != -1) {
          int vpos = kpos + searchKey.length();
          String value = "";
          char valChar = addressJson[vpos];
          if (valChar == '"' && addressJson.indexOf("\"", vpos + 1) != -1) {
            int vend = addressJson.indexOf("\"", vpos + 1);
            value = addressJson.substring(vpos + 1, vend);
          } else {
            int vend = addressJson.indexOf(",", vpos);
            if (vend == -1) vend = addressJson.length();
            value = addressJson.substring(vpos, vend);
            value.trim();
          }
          // Unicode karakterleri düzelt
          value = replaceSubstring(value, "\\u00fc", "ü");
          value = replaceSubstring(value, "\\u00e7", "ç");
          value = replaceSubstring(value, "\\u011f", "ğ");
          value = replaceSubstring(value, "\\u0131", "ı");
          value = replaceSubstring(value, "\\u00f6", "ö");
          value = replaceSubstring(value, "\\u015f", "ş");
          value = replaceSubstring(value, "\\u00c7", "Ç");
          value = replaceSubstring(value, "\\u011e", "Ğ");
          value = replaceSubstring(value, "\\u0130", "İ");
          value = replaceSubstring(value, "\\u00d6", "Ö");
          value = replaceSubstring(value, "\\u015e", "Ş");
          value = replaceSubstring(value, "\\u00dc", "Ü");

          if (value.length() > 0) {
            addressHtml += "<p><strong>" + label + ":</strong> " + value + "</p>";
          }
        }
      }
    }
  }

  // boundingbox bilgilerini bul
  String boundingBoxHtml = "";
  int bboxStart = jsonPayload.indexOf("\"boundingbox\":[");
  if (bboxStart != -1) {
    bboxStart += String("\"boundingbox\":[").length();
    int bboxEnd = jsonPayload.indexOf("]", bboxStart);
    if (bboxEnd != -1) {
      String bboxContent = jsonPayload.substring(bboxStart, bboxEnd);
      String bboxValues[4];
      int valCount = 0;
      int pos = 0;
      while (valCount < 4) {
        int valStart = bboxContent.indexOf("\"", pos);
        if (valStart == -1) break;
        int valEnd = bboxContent.indexOf("\"", valStart + 1);
        if (valEnd == -1) break;
        bboxValues[valCount++] = bboxContent.substring(valStart + 1, valEnd);
        pos = valEnd + 1;
        if (bboxContent[pos] == ',') pos++;
      }

      if (valCount == 4) {
        boundingBoxHtml += "<p><strong>Sınır Kutusu:</strong></p>";
        boundingBoxHtml += "<ul>";
        boundingBoxHtml += "<li><strong>Güney sınır (min enlem):</strong> " + bboxValues[0] + "</li>";
        boundingBoxHtml += "<li><strong>Kuzey sınır (max enlem):</strong> " + bboxValues[1] + "</li>";
        boundingBoxHtml += "<li><strong>Batı sınır (min boylam):</strong> " + bboxValues[2] + "</li>";
        boundingBoxHtml += "<li><strong>Doğu sınır (max boylam):</strong> " + bboxValues[3] + "</li>";
        boundingBoxHtml += "</ul>";
      }
    }
  }

  if (displayName.length() > 0 || addressHtml.length() > 0 || boundingBoxHtml.length() > 0) {
    htmlOutput += "<div class=\'location-info\'>";
    if (displayName.length() > 0) {
      htmlOutput += "<p><strong>Tam Adres:</strong> " + displayName + "</p>";
    }
    if (addressHtml.length() > 0) {
      htmlOutput += "<p><strong>Detaylar:</strong></p>";
      htmlOutput += addressHtml;
    }
    if (boundingBoxHtml.length() > 0) {
      htmlOutput += boundingBoxHtml;
    }
    htmlOutput += "</div>";
  } else {
    htmlOutput = "<div class=\'alert\'>Konum bilgileri alınamadı veya ayrıştırılamadı.</div>";
  }

  return htmlOutput;
}

// Reverse Geocoding sayfası
String generateReverseGeocodePage(String locationDataHtml = "") {
  String html = R"rawliteral(
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Tam Konum</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background: linear-gradient(135deg, #e0e7ef 0%, #f8fafc 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        margin: 0;
        padding: 20px;
      }
      .container {
        background: white;
        padding: 40px 40px 50px 40px;
        border-radius: 18px;
        box-shadow: 0 10px 32px rgba(0,0,0,0.13);
        max-width: 600px;
        width: 100%;
        box-sizing: border-box;
        margin: 30px 0;
        text-align: center;
      }
      h1 {
        color: #2f72bc;
        margin-bottom: 30px;
        font-weight: 700;
        font-size: 2.1rem;
        letter-spacing: 0.5px;
      }
      .location-info {
        margin-top: 25px;
        padding: 20px 25px;
        background: #f3f8fd;
        border-radius: 12px;
        color: #0b3e75;
        font-weight: 600;
        font-size: 1.05rem;
        text-align: left;
        user-select: text;
        box-shadow: 0 3px 10px rgba(0,0,0,0.08);
      }
      .location-info p {
        margin: 10px 0;
        line-height: 1.6;
        word-wrap: break-word;
      }
      .location-info strong {
        color: #2f72bc;
        margin-right: 8px;
      }
      .alert {
        text-align: center;
        font-weight: 600;
        margin-bottom: 25px;
        user-select: none;
        font-size: 1.1rem;
        color: #dc3545;
      }
      .back-btn {
        display: block;
        margin: 18px auto 0 auto;
        width: 100%;
        padding: 12px 0;
        font-size: 1.1rem;
        font-weight: 600;
        color: #2f72bc;
        background: #e9f5fe;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        text-decoration: none;
        transition: background 0.2s;
        text-align: center;
      }
      .back-btn:hover {
        background: #d0e7fa;
      }
      footer {
        margin-top: 35px;
        font-size: 14px;
        color: #777;
        text-align: center;
        user-select: none;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>)rawliteral" + String(titleText) + R"rawliteral(</h1>
      )rawliteral" + locationDataHtml + R"rawliteral(
      <a href="/anasayfa" class="back-btn">← Ana Sayfa</a>
      <footer>)rawliteral" + String(footerText) + R"rawliteral(</footer>
    </div>
  </body>
  </html>
  )rawliteral";
  return html;
}

// Hava Durumu sayfası
String generateWeatherPage(String weatherDataHtml = "") {
  String html = R"rawliteral(
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Hava Durumu</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background: linear-gradient(135deg, #e0e7ef 0%, #f8fafc 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        margin: 0;
        padding: 20px;
      }
      .container {
        background: white;
        padding: 40px 40px 50px 40px;
        border-radius: 18px;
        box-shadow: 0 10px 32px rgba(0,0,0,0.13);
        max-width: 500px;
        width: 100%;
        box-sizing: border-box;
        margin: 30px 0;
        text-align: center;
      }
      h1 {
        color: #2f72bc;
        margin-bottom: 30px;
        font-weight: 700;
        font-size: 2.1rem;
        letter-spacing: 0.5px;
      }
      .weather-info {
        margin-top: 25px;
        padding: 20px 25px;
        background: #f3f8fd;
        border-radius: 12px;
        color: #0b3e75;
        font-weight: 600;
        font-size: 1.05rem;
        text-align: left;
        user-select: text;
        box-shadow: 0 3px 10px rgba(0,0,0,0.08);
        line-height: 1.8;
      }
      .weather-info strong {
        color: #2f72bc;
        margin-right: 8px;
      }
      .alert {
        text-align: center;
        font-weight: 600;
        margin-bottom: 25px;
        user-select: none;
        font-size: 1.1rem;
        color: #dc3545;
      }
      .back-btn {
        display: block;
        margin: 18px auto 0 auto;
        width: 100%;
        padding: 12px 0;
        font-size: 1.1rem;
        font-weight: 600;
        color: #2f72bc;
        background: #e9f5fe;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        text-decoration: none;
        transition: background 0.2s;
        text-align: center;
      }
      .back-btn:hover {
        background: #d0e7fa;
      }
      footer {
        margin-top: 35px;
        font-size: 14px;
        color: #777;
        text-align: center;
        user-select: none;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>)rawliteral" + String(titleText) + R"rawliteral(</h1>
      )rawliteral" + weatherDataHtml + R"rawliteral(
      <a href="/anasayfa" class="back-btn">← Ana Sayfa</a>
      <footer>)rawliteral" + String(footerText) + R"rawliteral(</footer>
    </div>
  </body>
  </html>
  )rawliteral";
  return html;
}

// Ana sayfa
void handleHome() {
  server.send(200, "text/html", generateHomePage());
}

// Veri gönderme
void handleSend() {
  if (server.hasArg("field1") && server.hasArg("field2")) {
    String f1 = server.arg("field1");
    String f2 = server.arg("field2");
    if (f1.length() == 0 || f2.length() == 0) {
      server.send(200, "text/html", generateSendPage("Lütfen tüm alanları doldurun!", false));
      return;
    }
    String url = String("http://api.thingspeak.com/update") + "?api_key=" + apiKey + "&field1=" + f1 + "&field2=" + f2;
    HTTPClient http;

    Serial.print("Manuel Thingspeak URL: ");
    Serial.println(url);
    
    http.begin(url);
    int httpCode = http.GET();
    String payload = http.getString();
    http.end();

    Serial.print("Manuel Gönderme HTTP Kodu: ");
    Serial.println(httpCode);
    Serial.print("Manuel Gönderme Yanıtı: ");
    Serial.println(payload);

    if (httpCode == 200 && payload != "0") {
      server.send(200, "text/html", generateSendPage("✅ Başarıyla Thingspeak'e gönderildi! Entry ID: " + payload, true));
    } else {
      server.send(200, "text/html", generateSendPage("❌ Gönderme başarısız! HTTP Kodu: " + String(httpCode) + ", Yanıt: " + payload, false));
    }
  } else {
    server.send(200, "text/html", generateSendPage());
  }
}

// Verileri listele
void handleList() {
  fetchAndBuildTables();
  server.send(200, "text/html", generateListPage());
}

// GPS verileri sayfası
void handleGps() {
  server.send(200, "text/html", generateGpsPage());
}

// AJAX isteği ile GPS verilerini döndür
void handleGetGpsData() {
  String json = "{";
  json += "\"status\": \"" + gpsStatusMessage + "\",";
  json += "\"location\": \"" + lastGpsLocation + "\",";
  
  // Enlem ve boylamı JSON yanıtına ekle (BU KISIM KALDIRILACAK)
  // if (gps.location.isValid()) {
  //   json += "\"latitude\": \"" + String(gps.location.lat(), 6) + "\",";
  //   json += "\"longitude\": \"" + String(gps.location.lng(), 6) + "\",";
  // } else {
  //   json += "\"latitude\": \"N/A\",";
  //   json += "\"longitude\": \"N/A\",";
  // }

  json += "\"full_data\": \"" + lastGpsDataFull + "\",";
  json += "\"raw_gprmc\": \"" + lastRawGPRMC + "\"";
  json += "}";
  server.sendHeader("Access-Control-Allow-Origin", "*"); // CORS başlığı eklendi
  server.send(200, "application/json", json);
}

// Thingspeak'e GPS verisi gönderir
void sendGpsDataToThingspeakAutomatic(float latitude, float longitude) {
  HTTPClient http;
  String url = String("http://api.thingspeak.com/update") + "?api_key=" + apiKey + "&field1=" + String(latitude, 6) + "&field2=" + String(longitude, 6);
  Serial.print("Thingspeak'e GPS gönderiliyor: ");
  Serial.println(url);
  http.begin(url);
  int httpCode = http.GET();
  String payload = http.getString();
  http.end();

  Serial.print("Otomatik Gönderme HTTP Kodu: ");
  Serial.println(httpCode);
  Serial.print("Otomatik Gönderme Yanıtı: ");
  Serial.println(payload);

  if (httpCode == 200 && payload != "0") {
    Serial.println("✅ GPS başarıyla Thingspeak'e gönderildi! Entry ID: " + payload);
  } else {
    Serial.println("❌ GPS gönderme başarısız! HTTP Kodu: " + String(httpCode) + ", Yanıt: " + payload);
  }
}

// Tam Konum (Reverse Geocoding) sayfası
void handleReverseGeocode() {
  String locationDataHtml = "";
  if (gps.location.isValid()) {
    float lat = gps.location.lat();
    float lon = gps.location.lng();
    
    String url = "https://us1.locationiq.com/v1/reverse?key=" + String(locationIQApiKey) + "&lat=" + String(lat, 6) + "&lon=" + String(lon, 6) + "&format=json";
    Serial.print("LocationIQ URL: ");
    Serial.println(url);

    HTTPClient http;
    http.begin(url);
    int httpCode = http.GET();
    
    if (httpCode == HTTP_CODE_OK) {
      String payload = http.getString();
      Serial.print("LocationIQ Yanıtı: ");
      Serial.println(payload);
      locationDataHtml = parseLocationIQJson(payload);
    } else {
      locationDataHtml = "<div class=\'alert\'>Konum servisine bağlanılamadı. HTTP Kodu: " + String(httpCode) + "</div>";
      Serial.print("LocationIQ Hatası: ");
      Serial.println(httpCode);
    }
    http.end();
  } else {
    locationDataHtml = "<div class=\'alert\'>GPS konumu henüz aktif değil veya geçersiz. Lütfen GPS verilerini bekleyin.</div>";
  }
  server.send(200, "text/html", generateReverseGeocodePage(locationDataHtml));
}

// Harita sayfası
void handleMaps() {
  server.send(200, "text/html", generateMapsPage());
}

// Hava Durumu sayfası
void handleWeather() {
  String weatherDataHtml = "";
  if (gps.location.isValid()) {
    float lat = gps.location.lat();
    float lon = gps.location.lng();
    
    String url = "https://api.open-meteo.com/v1/forecast?latitude=" + String(lat, 6) + "&longitude=" + String(lon, 6) + "&current_weather=true";
    Serial.print("Open-Meteo URL: ");
    Serial.println(url);

    HTTPClient http;
    http.begin(url);
    int httpCode = http.GET();
    
    if (httpCode == HTTP_CODE_OK) {
      String payload = http.getString();
      Serial.print("Open-Meteo Yanıtı: ");
      Serial.println(payload);

      // current_weather objesini bul
      int cwStart = payload.indexOf("\"current_weather\":{");
      int cwEnd = payload.indexOf("}", cwStart + 1);
      String currentWeatherJson = "";
      if (cwStart != -1 && cwEnd != -1) {
        currentWeatherJson = payload.substring(cwStart + String("\"current_weather\":").length(), cwEnd + 1);
        Serial.print("Current Weather JSON: ");
        Serial.println(currentWeatherJson);
      } else {
        weatherDataHtml = "<div class=\'alert\'>Hava durumu verisi bulunamadı.</div>";
        server.send(200, "text/html", generateWeatherPage(weatherDataHtml));
        http.end();
        return;
      }

      // JSON ayrıştırma ve HTML oluşturma
      String time = "N/A";
      String temperature = "N/A";
      String windspeed = "N/A";
      String winddirection = "N/A";
      String weathercode = "N/A";

      // time
      int timeStart = currentWeatherJson.indexOf("\"time\":\"");
      if (timeStart != -1) {
        timeStart += String("\"time\":\"").length();
        int timeEnd = currentWeatherJson.indexOf("\"", timeStart);
        if (timeEnd != -1) {
          time = currentWeatherJson.substring(timeStart, timeEnd);
          // Tarih ve saati ayır (örn: 2025-06-07T22:30 -> 07 Haziran 2025, 22:30 UTC)
          String datePart = time.substring(0, 10); // YYYY-MM-DD
          String timePart = time.substring(11, 16); // HH:MM

          String year = datePart.substring(0, 4);
          String monthNum = datePart.substring(5, 7);
          String day = datePart.substring(8, 10);

          String monthName;
          if (monthNum == "01") monthName = "Ocak";
          else if (monthNum == "02") monthName = "Şubat";
          else if (monthNum == "03") monthName = "Mart";
          else if (monthNum == "04") monthName = "Nisan";
          else if (monthNum == "05") monthName = "Mayıs";
          else if (monthNum == "06") monthName = "Haziran";
          else if (monthNum == "07") monthName = "Temmuz";
          else if (monthNum == "08") monthName = "Ağustos";
          else if (monthNum == "09") monthName = "Eylül";
          else if (monthNum == "10") monthName = "Ekim";
          else if (monthNum == "11") monthName = "Kasım";
          else if (monthNum == "12") monthName = "Aralık";

          time = day + " " + monthName + " " + year + ", " + timePart + " UTC";
        }
      }

      // temperature
      int tempStart = currentWeatherJson.indexOf("\"temperature\":");
      if (tempStart != -1) {
        tempStart += String("\"temperature\":").length();
        int tempEnd = currentWeatherJson.indexOf(",", tempStart);
        if (tempEnd == -1) tempEnd = currentWeatherJson.indexOf("}", tempStart);
        if (tempEnd != -1) {
          temperature = currentWeatherJson.substring(tempStart, tempEnd);
        }
      }

      // windspeed
      int wsStart = currentWeatherJson.indexOf("\"windspeed\":");
      if (wsStart != -1) {
        wsStart += String("\"windspeed\":").length();
        int wsEnd = currentWeatherJson.indexOf(",", wsStart);
        if (wsEnd == -1) wsEnd = currentWeatherJson.indexOf("}", wsStart);
        if (wsEnd != -1) {
          windspeed = currentWeatherJson.substring(wsStart, wsEnd);
        }
      }

      // winddirection
      int wdStart = currentWeatherJson.indexOf("\"winddirection\":");
      if (wdStart != -1) {
        wdStart += String("\"winddirection\":").length();
        int wdEnd = currentWeatherJson.indexOf(",", wdStart);
        if (wdEnd == -1) wdEnd = currentWeatherJson.indexOf("}", wdStart);
        if (wdEnd != -1) {
          winddirection = currentWeatherJson.substring(wdStart, wdEnd);
        }
      }

      // weathercode
      int wcStart = currentWeatherJson.indexOf("\"weathercode\":");
      if (wcStart != -1) {
        wcStart += String("\"weathercode\":").length();
        int wcEnd = currentWeatherJson.indexOf(",", wcStart);
        if (wcEnd == -1) wcEnd = currentWeatherJson.indexOf("}", wcStart);
        if (wcEnd != -1) {
          weathercode = currentWeatherJson.substring(wcStart, wcEnd);
        }
      }
      
      // Hava durumu koduna göre açıklama
      String weatherDescription = "Bilinmiyor";
      int wc = weathercode.toInt();
      if (wc == 0) weatherDescription = "Açık";
      else if (wc == 1 || wc == 2 || wc == 3) weatherDescription = "Çoğunlukla Açık / Parçalı Bulutlu";
      else if (wc == 45 || wc == 48) weatherDescription = "Sisli";
      else if (wc == 51 || wc == 53 || wc == 55) weatherDescription = "Çisenti";
      else if (wc == 56 || wc == 57) weatherDescription = "Dondurucu Çisenti";
      else if (wc == 61 || wc == 63 || wc == 65) weatherDescription = "Yağmurlu";
      else if (wc == 66 || wc == 67) weatherDescription = "Dondurucu Yağmur";
      else if (wc == 71 || wc == 73 || wc == 75) weatherDescription = "Kar Yağışı";
      else if (wc == 77) weatherDescription = "Kar Tanesi";
      else if (wc == 80 || wc == 81 || wc == 82) weatherDescription = "Sağanak Yağış";
      else if (wc == 85 || wc == 86) weatherDescription = "Kar Sağanağı";
      else if (wc == 95) weatherDescription = "Fırtına";
      else if (wc == 96 || wc == 99) weatherDescription = "Dolu ile Fırtına";

      // is_day
      String isDayStr = "N/A";
      int isDayStart = currentWeatherJson.indexOf("\"is_day\":");
      if (isDayStart != -1) {
        isDayStart += String("\"is_day\":").length();
        int isDayEnd = currentWeatherJson.indexOf("}", isDayStart); // is_day son alanı olabilir
        if (isDayEnd == -1) isDayEnd = currentWeatherJson.indexOf(",", isDayStart); // veya başka bir alan varsa virgülle biter
        if (isDayEnd != -1) {
          isDayStr = currentWeatherJson.substring(isDayStart, isDayEnd);
        }
      }
      
      String dayNightStatus = (isDayStr == "1") ? "Gündüz" : "Gece";

      weatherDataHtml += "<div class=\'weather-info\'>";
      weatherDataHtml += "<p><strong>Bugünkü Hava Durumu – </strong>" + time + "</p>";
      weatherDataHtml += "<p>🌡️ <strong>Sıcaklık:</strong> " + temperature + "°C</p>";
      weatherDataHtml += "<p>🌬️ <strong>Rüzgar:</strong> " + windspeed + " km/h (" + winddirection + "° yönünden)</p>";
      weatherDataHtml += "<p>" + dayNightStatus + " – <strong>Durum:</strong> " + weatherDescription + "</p>";
      weatherDataHtml += "</div>";

    } else {
      weatherDataHtml = "<div class=\'alert\'>Hava durumu servisine bağlanılamadı. HTTP Kodu: " + String(httpCode) + "</div>";
      Serial.print("Open-Meteo Hatası: ");
      Serial.println(httpCode);
    }
    http.end();
  } else {
    weatherDataHtml = "<div class=\'alert\'>GPS konumu henüz aktif değil veya geçersiz. Hava durumu için konum bekleniyor.</div>";
  }
  server.send(200, "text/html", generateWeatherPage(weatherDataHtml));
}

void setup() {
  Serial.begin(115200);

  // Statik IP ayarları
  IPAddress localIP(192, 168, 1, 200);
  IPAddress gateway(192, 168, 1, 1);
  IPAddress subnet(255, 255, 255, 0);
  IPAddress primaryDNS(192, 168, 1, 1); // İsteğe bağlı, ağ geçidi veya 8.8.8.8 olabilir

  WiFi.config(localIP, gateway, subnet, primaryDNS);
  
  WiFi.begin(ssid, password);
  Serial.print("WiFi bağlanıyor");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi bağlandı!");
  Serial.print("IP adresi: ");
  Serial.println(WiFi.localIP());

  Serial1.begin(9600, SERIAL_8N1, 16, 17); // GPS modülü için Serial1'i başlat (RX: 16, TX: 17)

  server.on("/anasayfa", handleHome);
  server.on("/veri_gonder", handleSend);
  server.on("/verileri_listele", handleList);
  server.on("/gps_verileri", handleGps);
  server.on("/get_gps_data", handleGetGpsData);
  server.on("/reverse_geocode", handleReverseGeocode);
  server.on("/haritada_goster", handleMaps);
  server.on("/hava_durumu", handleWeather);
  server.on("/export_list_data", handleExportListData); // Yeni dışa aktarma işleyicisi

  // İlk açılışta ana sayfaya yönlendir
  server.on("/", []() {
    server.sendHeader("Location", "/anasayfa", true);
    server.send(302, "text/plain", "");
  });

  server.begin();
  Serial.println("HTTP sunucu başladı.");
}

void loop() {
  server.handleClient();

  static String NMEA_sentence_buffer; // Gelen NMEA cümlesini tutmak için statik tampon
  static String previousGpsStatusMessage = ""; // Önceki GPS durum mesajını tutmak için
  static String previousGpsLocation = "";     // Önceki GPS konum mesajını tutmak için
  static String previousGpsDataFull = "";     // Önceki tam GPS veri mesajını tutmak için

  while (Serial1.available() > 0) {
    char incomingChar = Serial1.read();
    NMEA_sentence_buffer += incomingChar;

    if (incomingChar == 10) { // NMEA cümleleri \r\n ile biter (10 ASCII değeri \n için)
      NMEA_sentence_buffer.trim(); // Yeni satır ve satır başı karakterlerini kaldır
      if (NMEA_sentence_buffer.startsWith("$GPRMC")) {
        lastRawGPRMC = NMEA_sentence_buffer;
      }
      NMEA_sentence_buffer = ""; // Tamponu bir sonraki cümle için sıfırla
    }

    if (gps.encode(incomingChar)) {
      // Yeni GPS verisi işlendi
      bool isGPRMC_Status_V = lastRawGPRMC.indexOf(",V,") != -1;

      if (gps.location.isValid() && !isGPRMC_Status_V) { // Sadece TinyGPS geçerli diyorsa VE ham GPRMC 'V' (geçersiz) değilse
        lastGpsLocation = "Enlem: " + String(gps.location.lat(), 6) + ", Boylam: " + String(gps.location.lng(), 6);
        gpsStatusMessage = "Aktif (Uydu: " + String(gps.satellites.value()) + ")";
        
        // Thingspeak'e otomatik gönderme
        if (millis() - lastGpsSendTime >= GPS_SEND_INTERVAL_MS) {
          sendGpsDataToThingspeakAutomatic(gps.location.lat(), gps.location.lng());
          lastGpsSendTime = millis();
        }

      } else { // TinyGPS geçersiz diyorsa VEYA ham GPRMC 'V' ise
        lastGpsLocation = "Konum geçersiz";
        if (isGPRMC_Status_V) {
          gpsStatusMessage = "GPS aktif değil (geçersiz veri)"; // 'V' durumu için özel mesaj
        } else {
          gpsStatusMessage = "Uydu bekleniyor..."; // Genel pasif/geçersiz mesaj
        }
        // Bu 'else' bloğunda Thingspeak'e veri gönderilmez, bu istenen davranıştır.
      }

      lastGpsDataFull = "Uydu: " + String(gps.satellites.value());
      if (gps.location.isValid() && !isGPRMC_Status_V) { // Sadece gerçekten geçerliyse detaylı bilgi ekle
        lastGpsDataFull += ", Hız: " + String(gps.speed.kmph()) + " km/s";
        if (gps.course.isValid()) {
          lastGpsDataFull += ", Yön: " + String(gps.course.deg(), 2) + "°";
        }
        lastGpsDataFull += ", Yükseklik: " + String(gps.altitude.meters()) + " m";
        lastGpsDataFull += ", Zaman: " + String(gps.time.hour()) + ":" + String(gps.time.minute()) + ":" + String(gps.time.second());
      } else {
        lastGpsDataFull += ", Hız: N/A, Yön: N/A, Yükseklik: N/A, Zaman: N/A"; // Geçersiz veri için N/A göster
      }

      // Sadece durum değiştiyse konsola yazdır
      if (lastGpsLocation != previousGpsLocation) {
        Serial.println(lastGpsLocation);
        previousGpsLocation = lastGpsLocation;
      }
      if (gpsStatusMessage != previousGpsStatusMessage) {
        Serial.println(gpsStatusMessage);
        previousGpsStatusMessage = gpsStatusMessage;
      }
      if (lastGpsDataFull != previousGpsDataFull) {
        Serial.println(lastGpsDataFull);
        previousGpsDataFull = lastGpsDataFull;
      }
    }
  }

  if (millis() > 5000 && gps.charsProcessed() < 10) {
    // Bu kısım da sürekli basıyor olabilir. Eğer modül bağlı değilse, bunu da sadece bir kez basacak şekilde değiştirmeliyiz.
    // Bunun için de ayrı bir flag veya önceki durum kontrolü kullanabiliriz.
    // Şimdilik sadece user'ın istediği "Konum geçersiz" mesajı için değişiklik yapıyorum.
    // Ancak bu kısım da sürekli aynı mesajı basıyorsa benzer bir mantıkla ele alınmalı.
    String currentGpsModuleStatus = "GPS modülü bağlı değil veya veri yok!";
    String currentGpsLocationNA = "Enlem: N/A, Boylam: N/A";
    String currentGpsDataFullEmpty = "";

    if (currentGpsModuleStatus != previousGpsStatusMessage) {
        gpsStatusMessage = currentGpsModuleStatus; // gpsStatusMessage'ı güncelle
        Serial.println(gpsStatusMessage);
        previousGpsStatusMessage = gpsStatusMessage;
    }
    if (currentGpsLocationNA != previousGpsLocation) {
        lastGpsLocation = currentGpsLocationNA; // lastGpsLocation'ı güncelle
        Serial.println(lastGpsLocation);
        previousGpsLocation = lastGpsLocation;
    }
    if (currentGpsDataFullEmpty != previousGpsDataFull) {
        lastGpsDataFull = currentGpsDataFullEmpty; // lastGpsDataFull'u güncelle
        Serial.println(lastGpsDataFull);
        previousGpsDataFull = lastGpsDataFull;
    }
  }
}

void handleExportListData() {
  Serial.println("handleExportListData: Fonksiyon başladı.");
  HTTPClient http;
  String url = "https://api.thingspeak.com/channels/" + String(channelID) + "/feeds.json?api_key=" + String(readAPIKey) + "&results=100";
  http.begin(url);
  Serial.println("handleExportListData: HTTP isteği başlatılıyor.");
  int httpCode = http.GET();
  String payload = "";

  if (httpCode == HTTP_CODE_OK) {
    Serial.println("handleExportListData: HTTP isteği başarılı. Payload okunuyor.");
    payload = http.getString();
    Serial.print("handleExportListData: Payload boyutu: ");
    Serial.println(payload.length());
  } else {
    Serial.print("handleExportListData: Thingspeak API Hatası: ");
    Serial.println(httpCode);
    server.send(500, "text/plain", "Veriler Thingspeak'ten çekilemedi.");
    http.end();
    return;
  }
  http.end();
  Serial.println("handleExportListData: HTTP bağlantısı kapatıldı.");

  String exportText = "Thingspeak Veri Listesi (Son 100 Kayıt)\n";
  exportText += "-------------------------------------\n\n";

  // Sabit sütun genişlikleri
  const int createdAtWidth = 22; // created_at: YYYY-MM-DDTHH:MM:SSZ (örn: 2023-10-27T10:30:00Z)
  const int entryIdWidth = 10;   // entry_id: genelde 1-5 basamak
  const int latitudeWidth = 12;  // Enlem: örn: 38.xxxxxx
  const int longitudeWidth = 12; // Boylam: örn: 32.xxxxxx

  // Başlıkları oluştur ve hizala
  exportText += padRight("created_at", createdAtWidth);
  exportText += padRight("entry_id", entryIdWidth);
  exportText += padRight("Enlem", latitudeWidth);
  exportText += padRight("Boylam", longitudeWidth);
  exportText += "\n";

  // Ayırıcı çizgiyi oluştur
  for (int i = 0; i < createdAtWidth; i++) exportText += "-";
  for (int i = 0; i < entryIdWidth; i++) exportText += "-";
  for (int i = 0; i < latitudeWidth; i++) exportText += "-";
  for (int i = 0; i < longitudeWidth; i++) exportText += "-";
  exportText += "\n";
  Serial.println("handleExportListData: Başlıklar ve ayırıcı oluşturuldu.");

  // "feeds" kısmını bul
  int feedsStart = payload.indexOf("\"feeds\":[");
  int feedsEnd = payload.lastIndexOf("]}");

  if (feedsStart == -1 || feedsEnd == -1) {
    Serial.println("handleExportListData: Feeds JSON ayrıştırma hatası.");
    server.send(500, "text/plain", "Veri ayrıştırma hatası: 'feeds' bulunamadı.");
    return;
  }
  String feedsJson = payload.substring(feedsStart + 8, feedsEnd + 1);
  Serial.println("handleExportListData: Feeds JSON alındı.");

  // Her feed objesini işleyerek doğrudan exportText'e ekle
  int searchPos = 0;
  int feedCount = 0;
  while (true) {
    int objStart = feedsJson.indexOf('{', searchPos);
    int objEnd = feedsJson.indexOf('}', objStart);

    if (objStart == -1 || objEnd == -1) break;

    String obj = feedsJson.substring(objStart + 1, objEnd);
    
    String createdAt = "N/A";
    String entryId = "N/A";
    String field1 = "N/A"; // Enlem
    String field2 = "N/A"; // Boylam

    // created_at
    int kpos = obj.indexOf("\"created_at\":\"");
    if (kpos != -1) {
      int vpos = kpos + String("\"created_at\":\"").length();
      int vend = obj.indexOf('"', vpos);
      if (vend != -1) createdAt = obj.substring(vpos, vend);
    }

    // entry_id
    kpos = obj.indexOf("\"entry_id\":");
    if (kpos != -1) {
      int vpos = kpos + String("\"entry_id\":").length();
      int vend = obj.indexOf(',', vpos);
      if (vend == -1) vend = obj.length(); // Son alan olabilir
      entryId = obj.substring(vpos, vend);
      entryId.trim();
    }

    // field1 (Enlem)
    kpos = obj.indexOf("\"field1\":");
    if (kpos != -1) {
      int vpos = kpos + String("\"field1\":").length();
      int vend = obj.indexOf(',', vpos);
      if (vend == -1) vend = obj.length(); // Son alan olabilir
      field1 = obj.substring(vpos, vend);
      field1.trim();
    }

    // field2 (Boylam)
    kpos = obj.indexOf("\"field2\":");
    if (kpos != -1) {
      int vpos = kpos + String("\"field2\":").length();
      int vend = obj.indexOf(',', vpos);
      if (vend == -1) vend = obj.length(); // Son alan olabilir
      field2 = obj.substring(vpos, vend);
      field2.trim();
    }
    
    // Satırı exportText'e ekle
    exportText += padRight(createdAt, createdAtWidth);
    exportText += padRight(entryId, entryIdWidth);
    exportText += padRight(field1, latitudeWidth);
    exportText += padRight(field2, longitudeWidth);
    exportText += "\n";
    Serial.print("handleExportListData: İşlenen feed: ");
    Serial.println(feedCount);

    feedCount++;
    searchPos = objEnd + 1;
    if (searchPos >= feedsJson.length() || feedCount >= 100) break;
  }
  Serial.println("handleExportListData: Tüm feedler işlendi.");

  server.sendHeader("Content-Disposition", "attachment; filename=\"veri_listesi.txt\"");
  server.send(200, "text/plain", exportText);
  Serial.println("handleExportListData: Dosya gönderildi. Fonksiyon sonlandı.");
}