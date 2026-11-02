// Server-to-server database gateway. Raw credentials and user sessions never enter browser code.
const expected='96bb4931a3d05ca87306c5b6903e55622057217deb9c466496f0c7cd8012169f';
function equal(a:string,b:string){if(a.length!==b.length)return false;let n=0;for(let i=0;i<a.length;i++)n|=a.charCodeAt(i)^b.charCodeAt(i);return n===0;}
export async function handler(req:Request){
 const json=(body:unknown,status=200)=>Response.json(body,{status,headers:{'Cache-Control':'no-store'}});
 if(req.method!=='POST')return json({error:'Method not allowed'},405);
 const key=req.headers.get('x-jtp-key')||'';
 if(key.length!==64)return json({error:'Forbidden'},403);
 const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(key))),x=>x.toString(16).padStart(2,'0')).join('');
 if(!equal(hash,expected))return json({error:'Forbidden'},403);
 try{
  const text=await req.text();if(text.length>20000000)return json({error:'Request too large'},413);
  const p=JSON.parse(text);
  const rpc=p.action==='batch'?'jtp_batch':null;
  if(!rpc)return json({error:'Invalid action'},400);
  const body={statements:p.statements};
  const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const r=await fetch(Deno.env.get('SUPABASE_URL')+'/rest/v1/rpc/'+rpc,{method:'POST',redirect:'manual',headers:{'Content-Type':'application/json',apikey:serviceKey,Authorization:'Bearer '+serviceKey},body:JSON.stringify(body)});
  if(!r.ok){console.error('Database RPC failed',rpc,r.status);return json({error:'Database operation failed'},500);}
  return json(await r.json());
 }catch{return json({error:'Database request failed'},500);}
}
Deno.serve(handler);

