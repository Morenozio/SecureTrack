/**
 * Delete all today's attendance logs from Firestore using REST API.
 * Authenticates via Firebase CLI refresh token (already logged in).
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'fir-38b88';
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

function httpPost(hostname, urlPath, postData, contentType) {
    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname, path: urlPath, method: 'POST',
            headers: { 'Content-Type': contentType, 'Content-Length': Buffer.byteLength(postData) },
        }, res => {
            let data = ''; res.on('data', c => data += c);
            res.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve(data); } });
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
    });
}

function httpReq(method, urlPath, token) {
    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname: 'firestore.googleapis.com', port: 443,
            path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents${urlPath}`,
            method,
            headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
        }, res => {
            let data = ''; res.on('data', c => data += c);
            res.on('end', () => { try { resolve({ s: res.statusCode, d: JSON.parse(data) }); } catch { resolve({ s: res.statusCode, d: data }); } });
        });
        req.on('error', reject);
        req.end();
    });
}

async function main() {
    // 1. Get refresh token from Firebase CLI config
    const configFile = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
    if (!fs.existsSync(configFile)) {
        console.error('Firebase CLI not logged in. Run: npx firebase-tools login');
        process.exit(1);
    }
    const config = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
    const refreshToken = config.tokens?.refresh_token;
    if (!refreshToken) {
        console.error('No refresh token found. Run: npx firebase-tools login');
        process.exit(1);
    }

    // 2. Exchange refresh token for access token
    console.log('Refreshing access token...');
    const body = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}`;
    const tokenRes = await httpPost('oauth2.googleapis.com', '/token', body, 'application/x-www-form-urlencoded');

    if (!tokenRes.access_token) {
        console.error('Token refresh failed:', tokenRes);
        process.exit(1);
    }
    const token = tokenRes.access_token;
    console.log('Got access token.');

    // 3. List attendance_logs
    console.log('\nFetching attendance_logs...');
    const res = await httpReq('GET', '/attendance_logs?pageSize=500', token);
    if (res.s !== 200) {
        console.error('Failed:', res.d);
        process.exit(1);
    }

    const docs = res.d.documents || [];
    console.log(`Total docs: ${docs.length}`);

    // 4. Filter today's docs
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today.getTime() + 86400000);

    const todayDocs = docs.filter(doc => {
        const ts = doc.fields?.checkIn?.timestampValue;
        if (!ts) return false;
        const d = new Date(ts);
        return d >= today && d < tomorrow;
    });

    if (todayDocs.length === 0) {
        console.log('\nNo logs for today. Already neutral!');
        return;
    }

    console.log(`Found ${todayDocs.length} log(s) for today (${today.toLocaleDateString()}). Deleting...`);

    // 5. Delete each
    for (const doc of todayDocs) {
        const docId = doc.name.split('/').pop();
        const userId = doc.fields?.userId?.stringValue || '?';
        const checkIn = doc.fields?.checkIn?.timestampValue || '?';
        console.log(`  - ${docId} | user: ${userId} | checkIn: ${checkIn}`);

        const del = await httpReq('DELETE', `/attendance_logs/${docId}`, token);
        if (del.s !== 200 && del.s !== 204) {
            console.error(`    FAIL: ${del.s}`, typeof del.d === 'object' ? del.d.error?.message : del.d);
        }
    }

    console.log(`\nDone! Deleted ${todayDocs.length} log(s). All employees are neutral.`);
}

main().catch(e => { console.error('Error:', e.message); process.exit(1); });
