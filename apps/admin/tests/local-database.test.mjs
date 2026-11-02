import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
const originalFetch=globalThis.fetch;
after(()=>{globalThis.fetch=originalFetch;});
async function database(development,configuration){
 let source=readFileSync(new URL('../lib/supabase-db.ts',import.meta.url),'utf8').replace("import {env} from 'cloudflare:workers';",'const env='+JSON.stringify(configuration)+';').replaceAll('import.meta.env',JSON.stringify({DEV:development}));
 source=stripTypeScriptTypes(source);
 return import('data:text/javascript;base64,'+Buffer.from(source).toString('base64')+'#'+Math.random());
}
test('local server key goes only to the Supabase RPC endpoint',async()=>{
 const {gateway}=await database(true,{JTP_SUPABASE_URL:'https://example.supabase.co',JTP_SUPABASE_LOCAL_SERVICE_KEY:'sb_secret_test'});
 globalThis.fetch=async(url,init)=>{assert.equal(url,'https://example.supabase.co/rest/v1/rpc/jtp_batch');assert.equal(init.headers.apikey,'sb_secret_test');assert.equal(init.headers.Authorization,undefined);assert.equal(init.redirect,'manual');assert.deepEqual(JSON.parse(init.body),{statements:[]});return Response.json([]);};
 assert.deepEqual(await gateway('batch',{statements:[]}),[]);
});
test('production ignores the local server key and requires its normal connection',async()=>{
 const {gateway}=await database(false,{JTP_SUPABASE_URL:'https://example.supabase.co',JTP_SUPABASE_LOCAL_SERVICE_KEY:'sb_secret_test'});
 globalThis.fetch=async()=>{throw Error('Unexpected network request');};
 await assert.rejects(gateway('batch',{statements:[]}),/server configuration is missing/);
});
test('production keeps the existing Edge Function authentication',async()=>{
 const {gateway}=await database(false,{JTP_SUPABASE_URL:'https://example.supabase.co',JTP_SUPABASE_LOCAL_SERVICE_KEY:'unused',JTP_SUPABASE_SECRET:'existing-gateway-key'});
 globalThis.fetch=async(url,init)=>{assert.equal(url,'https://example.supabase.co/functions/v1/jtp-database');assert.equal(init.headers['x-jtp-key'],'existing-gateway-key');assert.equal(init.headers.apikey,undefined);return Response.json([]);};
 assert.deepEqual(await gateway('batch',{statements:[]}),[]);
});
