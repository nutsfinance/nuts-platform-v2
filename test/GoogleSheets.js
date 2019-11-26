const fs = require('fs');
const readline = require('readline');
const {google} = require('googleapis');

const SCOPES = ['https://www.googleapis.com/auth/spreadsheets'];
const TOKEN_PATH = 'token.json';

function authorize(credentials) {
  const {client_secret, client_id, redirect_uris} = credentials.installed;
  const oAuth2Client = new google.auth.OAuth2(
      client_id, client_secret, redirect_uris[0]);
  return new Promise((resolve, reject) => {
    fs.readFile(TOKEN_PATH, (err, token) => {
      if (err) {
        return getNewToken(oAuth2Client);
      }
      oAuth2Client.setCredentials(JSON.parse(token));
      resolve(oAuth2Client);
    });
  });
}

function getNewToken(oAuth2Client) {
  const authUrl = oAuth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
  });
  console.log('Authorize this app by visiting this url:', authUrl);
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve, reject) => {
    rl.question('Enter the code from that page here: ', (code) => {
      rl.close();
      oAuth2Client.getToken(code, (err, token) => {
        if (err) {
          reject(err);
        }
        oAuth2Client.setCredentials(token);
        // Store the token to disk for later program executions
        fs.writeFile(TOKEN_PATH, JSON.stringify(token), (err) => {
          if (err) {
            reject(err);
          }
          console.log('Token stored to', TOKEN_PATH);
        });
        resolve(oAuth2Client);
      });
    });
  });
}

function readCredentials() {
  return new Promise((resolve, reject) => {
    fs.readFile('credentials.json', 'utf8', (err, content) => {
      if (err) {
        reject(err);
      }
      resolve(JSON.parse(content));
    });
  })
}

function storeCSV(path, title) {
  return readCredentials()
    .then(content => authorize(content))
    .then(client => createNewDocument(client, title))
    .then(([sheetId, auth]) => readCSV(path, sheetId, auth))
    .then(([content, auth, sheetId]) => writeCSV(auth, content, sheetId));
}

function createNewDocument(auth, title) {
  const sheets = google.sheets({version: 'v4', auth});
  let request = {
    resource: {
      properties: {
        title: title
      }
    },
    auth: auth
  };
  return new Promise((resolve, reject) => {
    sheets.spreadsheets.create(request, function(err, response) {
      if (err) {
        reject(error);
      }
      resolve([response.data.spreadsheetId, auth]);
    });
  });
}

function readCSV(path, sheetId, auth) {
  return new Promise((resolve, reject) => {
    fs.readFile(path, 'utf8', (err, content) => {
      if (err) {
        reject(err);
      }
      resolve([content, auth, sheetId]);;
    });
  });
}

function writeCSV(auth, content, sheetId) {
  const sheets = google.sheets({version: 'v4', auth});
  return new Promise((resolve, reject) => {
    let batchUpdateRequest = {
      spreadsheetId: sheetId,  // TODO: Update placeholder value.
      resource: {
        requests: [{
          pasteData: {
            coordinate: {
              sheetId: 0,
              rowIndex: 0,
              columnIndex: 0
            },
            data: content,
            type: "PASTE_NORMAL",
            delimiter: ","
          }
        }]
      },
      auth: auth,
    };
    sheets.spreadsheets.batchUpdate(batchUpdateRequest, function(err, response) {
      if (err) {
        reject(err);
      }
      resolve(sheetId);
    });
  });
}

module.exports = {
  storeCSV: storeCSV
};
