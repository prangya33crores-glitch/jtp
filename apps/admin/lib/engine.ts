export type Row = Record<string, any>;
export type State = {personnel:Row[]; shifts:Row[]; locations:Row[]; leaders:Row[]; policies:Row[]; leaves:Row[]; assignments:Row[]; payroll:Row[]; settings:Row; history:Row[]};
export const initial = ():State => ({personnel:[],shifts:[],locations:[],leaders:[],policies:[],leaves:[],assignments:[],payroll:[],settings:{divisor:'calendar'},history:[]});
export const uid=()=>crypto.randomUUID();
export function days(from:string,to:string) { if(!/^\d{4}-\d{2}-\d{2}$/.test(from)||!/^\d{4}-\d{2}-\d{2}$/.test(to))throw Error('Select valid dates.'); const result:string[]=[]; for(let d=new Date(from+'T00:00:00Z'),last=new Date(to+'T00:00:00Z');d<=last;d.setUTCDate(d.getUTCDate()+1)){result.push(d.toISOString().slice(0,10));if(result.length>366)throw Error('Choose a period of 366 days or less.');} if(!result.length)throw Error('End date must follow start date.'); return result; }
export function period(month:string,week:number){const last=new Date(Date.UTC(Number(month.slice(0,4)),Number(month.slice(5,7)),0)).getUTCDate();return {from:`${month}-${String([1,8,15,22][week-1]).padStart(2,'0')}`,to:`${month}-${String(week===4?last:week*7).padStart(2,'0')}`};}
export function leaveDays(l:Row,month?:string){return days(l.from,l.to).filter(d=>!month||d.startsWith(month)).length*(l.half?0.5:1);}
function interval(a:Row,s:State){const sh=s.shifts.find(x=>x.id===a.shift); if(!sh)throw Error('Shift no longer exists.');const start=Date.parse(a.date+'T'+sh.start+':00Z');let end=Date.parse(a.date+'T'+sh.end+':00Z');if(end<=start)end+=86400000;return [start,end];}
// Roster weeks are the four fixed periods per month, not ISO calendar weeks.
export function rosterPeriodIndex(date:string){
 const [year,month,day]=date.split('-').map(Number);
 return year*48+(month-1)*4+Math.min(3,Math.floor((day-1)/7));
}
function periodLabel(date:string){const day=Number(date.slice(8));const week=Math.min(4,Math.floor((day-1)/7)+1);const pr=period(date.slice(0,7),week);return `${pr.from} to ${pr.to}`;}
function checkAssignment(a:Row,s:State,others:Row[]){others=others.filter(b=>effectiveDuty(s,b));const p=s.personnel.find(p=>p.id===a.person);if(!p||p.status!=='Active')throw Error('Choose active personnel.');if(a.date<p.joined)throw Error('Duty cannot precede date of joining.');if(!s.locations.some(x=>x.id===a.location&&x.status==='Active')||!s.shifts.some(x=>x.id===a.shift&&x.status==='Active'))throw Error('Choose an active location and shift.');if(s.leaves.some(l=>l.person===a.person&&l.status==='Approved'&&a.date>=l.from&&a.date<=l.to))throw Error(`${p.name} has approved leave on ${a.date}.`);const [start,end]=interval(a,s);if(others.some(b=>{if(b.person!==a.person||b.id===a.id)return false;const [bs,be]=interval(b,s);return start<be&&end>bs;}))throw Error(`${p.name} already has an overlapping shift on ${a.date}.`);
 const targetPeriod=rosterPeriodIndex(a.date);
 const conflict=others.find(b=>b.id!==a.id&&b.person===a.person&&b.shift===a.shift&&Math.abs(rosterPeriodIndex(b.date)-targetPeriod)===1);
 if(conflict){const shift=s.shifts.find(x=>x.id===a.shift)?.name||'this shift';throw Error(`Weekly rotation: ${p.name} cannot repeat ${shift} in consecutive roster periods (${periodLabel(conflict.date)} and ${periodLabel(a.date)}). Select a different shift.`);}
}
export function apply(s:State,action:string,p:Row,now:Date=new Date()):State {
const next=structuredClone(s); const allowed=['personnel','shifts','locations','leaders','policies'];
if(action==='seedDemoPersonnel'){
 for(let n=1;n<=180;n++){const suffix=String(n).padStart(3,'0');const id='demo-jtp-'+suffix;if(next.personnel.some(x=>x.id===id||x.code==='DEMO'+suffix))continue;next.personnel.push({id,code:'DEMO'+suffix,name:'Dummy JTP '+suffix,mobile:String(n).padStart(10,'0'),gender:n%3===0?'Female':'Male',joined:'2026-10-01',salary:15000,status:'Active',designation:'JTP',address:'Sample address · Test data only',remarks:'DUMMY DATA — fictional employee and placeholder mobile. Replace before production use.',isDemo:true});}
 if(!next.shifts.length)next.shifts.push({id:'demo-morning',name:'Morning shift',start:'06:00',end:'14:00',status:'Active'},{id:'demo-evening',name:'Evening shift',start:'14:00',end:'22:00',status:'Active'},{id:'demo-night',name:'Night shift',start:'22:00',end:'06:00',status:'Active'});
 if(!next.locations.length)next.locations.push(...['A','B','C'].map(x=>({id:'demo-gate-'+x,name:'Sample Gate '+x,code:'DEMO-GATE-'+x,address:'Sample duty location',strength:62,status:'Active'})));
 if(!next.leaders.length)next.leaders.push(...['A','B','C'].map(x=>({id:'demo-leader-'+x,name:'Dummy Leader '+x,mobile:'0000000000',designation:'Shift Leader',status:'Active'})));
 next.personnel=next.personnel.filter(x=>!(x.isDemo&&/^demo-jtp-18[1-4]$/.test(x.id)&&!next.assignments.some(a=>a.person===x.id)&&!next.leaves.some(l=>l.person===x.id)&&!next.payroll.some(p=>p.person===x.id)));
 next.settings.demoPersonnelSeeded=true;next.settings.demoPersonnelSeededCount=180;
}
else if(action==='save'){
 if(!allowed.includes(p.collection))throw Error('Invalid master.');const r={...p.record};if(!r.name?.trim())throw Error('Name is required.');r.name=r.name.trim();r.status=r.status||'Active';const list=(next as any)[p.collection] as Row[];
 if(list.some(x=>x.id!==r.id&&x.name.toLowerCase()===r.name.toLowerCase()))throw Error('A record with this name already exists.');
 if(p.collection==='personnel'){if(!/^\d{10}$/.test(r.mobile))throw Error('Enter a 10 digit mobile number.');if(!r.joined)throw Error('Joining date is required.');if(!Number.isFinite(Number(r.salary))||Number(r.salary)<0)throw Error('Enter a valid salary.');r.salary=Number(r.salary);r.code=r.code||'JTP'+String(list.length+1).padStart(4,'0');if(list.some(x=>x.id!==r.id&&x.code===r.code))throw Error('JTP ID already exists.');}
 if(p.collection==='shifts'&&(!/^\d{2}:\d{2}$/.test(r.start)||!/^\d{2}:\d{2}$/.test(r.end)||r.start===r.end))throw Error('Choose different valid shift start and end times.');
 if(p.collection==='policies'&&(!(Number(r.entitlement)>=0)||!['Paid','Unpaid'].includes(r.classification)))throw Error('Enter a valid leave policy.');
 if(p.collection==='locations'&&!(Number(r.strength)>=0))throw Error('Required strength must be zero or more.');
 if(p.collection==='shifts'&&r.id&&next.assignments.some(a=>a.shift===r.id)){const old=list.find(x=>x.id===r.id);if(old&&(old.start!==r.start||old.end!==r.end))throw Error('This shift is used in duty records. Create a new shift to change its timings.');}
 const i=list.findIndex(x=>x.id===r.id);r.id=r.id||uid();if(i>=0)list[i]=r;else list.push(r);
}
else if(action==='leave'){
 const l:Row={...p,id:p.id||uid()};if(!next.personnel.some(x=>x.id===l.person))throw Error('Choose JTP personnel.');const policy=next.policies.find(x=>x.id===l.policy);if(!policy)throw Error('Choose a leave policy.');days(l.from,l.to);if(l.half&&l.from!==l.to)throw Error('Half-day leave must be for one date.');l.classification=policy.classification;l.type=policy.name;l.days=leaveDays(l);
 if(!['Pending','Approved','Rejected','Cancelled'].includes(l.status))throw Error('Invalid leave status.');
 const previous=next.leaves.find(x=>x.id===l.id);const lockedOld=previous&&next.payroll.some(x=>x.person===previous.person&&x.status!=='Draft'&&days(previous.from,previous.to).some(d=>d.startsWith(x.month)));if(lockedOld)throw Error('The original leave period has finalized payroll.');
 const locked=next.payroll.some(x=>x.person===l.person&&x.status!=='Draft'&&days(l.from,l.to).some(d=>d.startsWith(x.month)));if(locked)throw Error('Payroll is finalized for this leave period.');
 if(l.status==='Approved') {if(next.leaves.some(x=>x.id!==l.id&&x.person===l.person&&x.status==='Approved'&&l.from<=x.to&&l.to>=x.from))throw Error('An approved leave already overlaps these dates.');if(l.classification==='Paid'){const groups=new Map<string,number>();for(const d of days(l.from,l.to)){const key=policy.frequency==='Monthly'?d.slice(0,7):d.slice(0,4);groups.set(key,(groups.get(key)||0)+(l.half?0.5:1));}for(const [key,requested] of groups){const used=next.leaves.filter(x=>x.id!==l.id&&x.person===l.person&&x.policy===l.policy&&x.status==='Approved').reduce((a,x)=>a+days(x.from,x.to).filter(d=>d.startsWith(key)).length*(x.half?0.5:1),0);if(used+requested>Number(policy.entitlement))throw Error('Leave entitlement exceeded. Use unpaid leave or revise the policy.');}}/* Approved leave suppresses duty through effectiveDuty; retain originals for history. */}
 const i=next.leaves.findIndex(x=>x.id===l.id);if(i>=0)next.leaves[i]=l;else next.leaves.push(l);
 coverLeaveDuties(next,now);
}
else if(action==='autoRoster'){generateCurrentRoster(next,p,now);}
else if(action==='publishPeriod'){publishCurrentRoster(next,p,now);}
else if(action==='assign'){
 if(!Array.isArray(p.people)||!p.people.length)throw Error('Select at least one JTP.');const dates=days(p.from,p.to); const additions:Row[]=[];for(const person of p.people)for(const date of dates){const a={id:uid(),person,date,shift:p.shift,location:p.location,leader:p.leader,status:'Draft'};checkAssignment(a,next,[...next.assignments,...additions]);additions.push(a);}next.assignments.push(...additions);
}
else if(action==='publish'){const list=next.assignments.filter(a=>a.date.startsWith(p.month));if(!list.length)throw Error('Create assignments before publishing.');for(const a of list){checkAssignment(a,next,next.assignments);a.status='Published';}}
else if(action==='removeAssignment'){const a=next.assignments.find(x=>x.id===p.id);if(a&&(a.status==='Published'||a.date<currentRosterPeriod(now).from))throw Error('Published and historical duties cannot be removed.');next.assignments=next.assignments.filter(x=>x.id!==p.id);}
else if(action==='payroll'){
 if(!/^\d{4}-\d{2}$/.test(p.month))throw Error('Select a salary month.');const count=new Date(Number(p.month.slice(0,4)),Number(p.month.slice(5,7)),0).getDate();const eligible=next.personnel.filter(x=>x.status==='Active'&&x.joined<=p.month+'-'+count);if(!eligible.length)throw Error('No eligible active personnel.');
 for(const person of eligible){const existing=next.payroll.find(x=>x.person===person.id&&x.month===p.month);if(existing&&existing.status!=='Draft')continue;const salary=Number(person.salary);const employedDays=Math.min(count,days(person.joined>p.month+'-01'?person.joined:p.month+'-01',p.month+'-'+count).length);const base=salary*employedDays/count;const ls=next.leaves.filter(l=>l.person===person.id&&l.status==='Approved');const paid=ls.filter(l=>l.classification==='Paid').reduce((a,l)=>a+leaveDays(l,p.month),0);const unpaid=ls.filter(l=>l.classification==='Unpaid').reduce((a,l)=>a+leaveDays(l,p.month),0);const daily=salary/(next.settings.divisor==='30'?30:count);const deduction=Math.min(base,daily*unpaid);const r={id:existing?.id||uid(),person:person.id,name:person.name,code:person.code,month:p.month,monthlySalary:salary,base:Math.round(base*100)/100,paid,unpaid,daily,deduction:Math.round(deduction*100)/100,net:Math.round(Math.max(0,base-deduction)*100)/100,status:'Draft',generatedAt:new Date().toISOString()};if(existing)Object.assign(existing,r);else next.payroll.push(r);}
}
else if(action==='payrollStatus'){const r=next.payroll.find(x=>x.id===p.id);if(!r)throw Error('Salary record not found.');if((r.status==='Draft'&&p.status==='Approved')||(r.status==='Approved'&&p.status==='Paid'))r.status=p.status;else throw Error('Invalid salary status transition.');}
else if(action==='settings'){if(!['calendar','30'].includes(p.divisor))throw Error('Invalid deduction policy.');next.settings={...next.settings,divisor:p.divisor};}
else throw Error('Unknown action.');
next.history.unshift({id:uid(),action,at:new Date().toISOString(),details:action==='seedDemoPersonnel'?'180 dummy JTP personnel ready for duty assignment':action==='save'?`${p.collection}: ${p.record.name}`:action==='assign'?`${p.people.length} personnel • ${p.from} to ${p.to}`:action==='leave'?`${p.status} leave • ${p.from} to ${p.to}`:p.month||p.status||'Workspace updated'});next.history=next.history.slice(0,500);return next;
}

// Read-only, employee-scoped monthly schedule. Drafts are opt-in for admin review.
export function employeeSchedule(s:State,personId:string,month:string,includeDraft=false):Row[]{
 if(!personId||!s.personnel.some(p=>p.id===personId))return [];
 if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(month))throw Error('Select a valid month.');
 return days(month+'-01',period(month,4).to).flatMap(date=>{
  const leave=s.leaves.find(l=>l.person===personId&&l.status==='Approved'&&l.from<=date&&l.to>=date);
  if(leave)return [{date,status:'Leave',shift:leave.type,timing:leave.half?'Half day':'Full day',location:'—',leader:'—'}];
  const assignments=s.assignments.filter(a=>a.person===personId&&a.date===date&&effectiveDuty(s,a)&&(includeDraft||a.status==='Published'));
  if(!assignments.length)return [{date,status:'Not scheduled',shift:'—',timing:'—',location:'—',leader:'—'}];
  return assignments.map(a=>{const shift=s.shifts.find(sh=>sh.id===a.shift);return {date,status:a.status,shift:shift?.name||'Unknown shift',timing:shift?`${shift.start} – ${shift.end}${shift.end<shift.start?' (next day)':''}`:'—',location:s.locations.find(l=>l.id===a.location)?.name||'—',leader:s.leaders.find(l=>l.id===a.leader)?.name||'—'};}).sort((a,b)=>a.timing.localeCompare(b.timing));
 });
}

export function employeeLeaveRequest(state:State,person:string,input:Record<string,unknown>){
 if(!state.personnel.some(p=>p.id===person&&p.status==='Active'))throw Error('Employee account is not active.');
 const policy=state.policies.find(p=>p.id===input.policy&&p.status==='Active');if(!policy)throw Error('Choose an active leave type.');
 const {from,to,reason}=input;
 if(typeof from!=='string'||typeof to!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(from)||!/^\d{4}-\d{2}-\d{2}$/.test(to)||new Date(from+'T12:00:00Z').toISOString().slice(0,10)!==from||new Date(to+'T12:00:00Z').toISOString().slice(0,10)!==to)throw Error('Enter valid leave dates.');
 if(typeof reason!=='string'||!reason.trim()||reason.length>1000)throw Error('Enter a reason of up to 1000 characters.');
 if(state.leaves.some(l=>l.person===person&&['Pending','Approved'].includes(l.status)&&from<=l.to&&to>=l.from))throw Error('A pending or approved leave request already overlaps these dates.');
 return apply(state,'leave',{person,policy:policy.id,from,to,reason:reason.trim(),status:'Pending',half:false});
}

// Fixed monthly roster periods, evaluated against the server clock in IST.
export function currentRosterPeriod(now:Date=new Date()){
 const date=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);
 const month=date.slice(0,7),week=Math.min(4,Math.floor((Number(date.slice(8))-1)/7)+1);
 return {date,month,week,...period(month,week)};
}
function onApprovedLeave(s:State,person:string,date:string){return s.leaves.some(l=>l.person===person&&l.status==='Approved'&&date>=l.from&&date<=l.to);}
// Keep published originals intact. A leave cover is effective only while its original duty needs cover.
export function effectiveDuty(s:State,a:Row):boolean{
 if(onApprovedLeave(s,a.person,a.date))return false;
 if(a.replacesAssignment){const original=s.assignments.find(x=>x.id===a.replacesAssignment);return !!original&&onApprovedLeave(s,original.person,original.date);}
 return true;
}
function requireCurrentPeriod(p:Row,now:Date){const c=currentRosterPeriod(now);if((p.month!==undefined&&p.month!==c.month)||(p.week!==undefined&&p.week!==c.week))throw Error(`Only the current IST period (${c.from} to ${c.to}) is available.`);return c;}
function orderedActive(s:State){return s.personnel.filter(p=>p.status==='Active').sort((a,b)=>String(a.code||a.id).localeCompare(String(b.code||b.id)));}
function coverLeaveDuties(s:State,now:Date){
 const c=currentRosterPeriod(now),unfilled:Row[]=[];
 const originals=s.assignments.filter(a=>!a.replacesAssignment&&a.date>=c.date&&a.date<=c.to&&onApprovedLeave(s,a.person,a.date));
 for(const original of originals){
  if(s.assignments.some(a=>a.replacesAssignment===original.id&&effectiveDuty(s,a)))continue;
  const candidates=orderedActive(s).filter(p=>p.id!==original.person).sort((a,b)=>s.assignments.filter(x=>x.person===a.id&&x.date>=c.from&&x.date<=c.to&&effectiveDuty(s,x)).length-s.assignments.filter(x=>x.person===b.id&&x.date>=c.from&&x.date<=c.to&&effectiveDuty(s,x)).length);
  let covered=false;
  for(const person of candidates){const a={...original,id:uid(),person:person.id,replacesAssignment:original.id,autoGenerated:true};try{checkAssignment(a,s,s.assignments);s.assignments.push(a);covered=true;break}catch{}}
  if(!covered)unfilled.push({date:original.date,person:original.person,shift:original.shift,location:original.location,reason:'Approved leave: no eligible replacement without a shift or rotation conflict.'});
 }
 s.settings.rosterCoverage={from:c.from,to:c.to,unfilled};
 return unfilled;
}
function generateCurrentRoster(s:State,p:Row,now:Date){
 const c=requireCurrentPeriod(p,now);
 // Published periods are immutable; only leave-cover additions may be appended.
 if(s.assignments.some(a=>a.status==='Published'&&a.date>=c.from&&a.date<=c.to)){coverLeaveDuties(s,now);return;}
 const staff=orderedActive(s).filter(p=>!p.joined||p.joined<=c.to),shifts=s.shifts.filter(x=>x.status==='Active'),locations=s.locations.filter(x=>x.status==='Active'),leaders=s.leaders.filter(x=>x.status==='Active');
 if(!staff.length||!shifts.length||!locations.length)throw Error('Add active personnel, shifts and duty locations before automatic allocation.');
 const target=rosterPeriodIndex(c.from);
 const past=s.assignments.filter(a=>rosterPeriodIndex(a.date)<target&&!a.replacesAssignment);
 const published=past.filter(a=>a.status==='Published'||s.assignments.some(b=>b.replacesAssignment===a.id&&b.status==='Published')),history=published.length?published:past;
 const sourceIndex=history.length?Math.max(...history.map(a=>rosterPeriodIndex(a.date))):null;
 const previous=history.filter(a=>rosterPeriodIndex(a.date)===sourceIndex);
 // Each employee retains the last duty pattern of the previous roster (including multiple duties on that date).
 const sourcePeople=[...new Set(previous.map(a=>a.person))];
 const templates:Row[]=sourcePeople.length?sourcePeople.flatMap(person=>{const own=previous.filter(a=>a.person===person),last=own.reduce((d,a)=>a.date>d?a.date:d,'');return own.filter(a=>a.date===last)}):staff.map((person,i)=>({person:person.id,shift:shifts[i%shifts.length].id,location:locations[i%locations.length].id,leader:leaders.length?leaders[i%leaders.length].id:''}));
 const old=s.settings.rosterGeneration?.[c.from];
 const unfilled:Row[]=[];let added=0;
 for(const [i,t] of templates.entries()){
  const location=locations.find(l=>l.id===t.location)?.id||locations[i%locations.length].id;
  const leader=leaders.find(l=>l.id===t.leader)?.id||(leaders.length?leaders[i%leaders.length].id:'');
  const previousShift=shifts.findIndex(sh=>sh.id===t.shift);
  const start=previous.length?(previousShift+1+shifts.length)%shifts.length:Math.max(0,previousShift);
  const shiftOrder=Array.from({length:shifts.length},(_,n)=>shifts[(start+n)%shifts.length]);
  let selected=shiftOrder.find(sh=>days(c.from,c.to).every(date=>{
   if((!previous.length&&staff.some(p=>p.id===t.person&&p.joined>date))||onApprovedLeave(s,t.person,date)||s.assignments.some(a=>a.person===t.person&&a.date===date&&a.location===location&&effectiveDuty(s,a)))return true;
   try{checkAssignment({id:'candidate',person:t.person,date,shift:sh.id,location,leader},s,s.assignments);return true}catch{return false}
  }))?.id;
  // Leave slots retain the rotated duty shift, then seek a different eligible employee.
  selected=selected||shiftOrder.find(sh=>!s.assignments.some(a=>a.person===t.person&&a.shift===sh.id&&Math.abs(rosterPeriodIndex(a.date)-target)===1&&effectiveDuty(s,a)))?.id;
  for(const date of days(c.from,c.to)){
   if(!previous.length&&staff.some(p=>p.id===t.person&&p.joined>date))continue;
   const slot=`${c.from}:${t.person}:${t.shift}:${t.location}:${date}`;
   if(s.assignments.some(a=>a.autoSlot===slot&&effectiveDuty(s,a)))continue;
   if(s.assignments.some(a=>!a.replacesAssignment&&a.person===t.person&&a.date===date&&a.location===location&&a.shift===selected))continue;
   if(s.assignments.some(a=>a.person===t.person&&a.date===date&&a.location===location&&a.shift===selected&&effectiveDuty(s,a)))continue;
   const absent=onApprovedLeave(s,t.person,date)||!staff.some(x=>x.id===t.person&&x.joined<=date);
   const candidates=absent?staff.filter(x=>x.id!==t.person).sort((a,b)=>s.assignments.filter(x=>x.person===a.id&&x.date===date&&effectiveDuty(s,x)).length-s.assignments.filter(x=>x.person===b.id&&x.date===date&&effectiveDuty(s,x)).length):staff.filter(x=>x.id===t.person);
   let original:Row|undefined;
   if(selected&&onApprovedLeave(s,t.person,date)&&staff.some(p=>p.id===t.person&&p.joined<=date)){
    original={id:uid(),person:t.person,date,shift:selected,location,leader,status:'Draft',autoGenerated:true,autoSlot:slot};s.assignments.push(original);added++;
   }
   let created=false;
   for(const person of candidates){if(!selected)break;const a={id:uid(),person:person.id,date,shift:selected,location,leader,status:'Draft',autoGenerated:true,autoSlot:slot,...(absent?{coveringPerson:t.person}:{} ),...(original?{replacesAssignment:original.id}:{})};try{checkAssignment(a,s,s.assignments);s.assignments.push(a);added++;created=true;break}catch{}}
   if(!created)unfilled.push({date,person:t.person,shift:selected||t.shift,location,reason:absent?'No eligible replacement available.':'No eligible shift without an overlap or consecutive-period rotation conflict.'});
  }
 }
 s.settings.rosterGeneration={...s.settings.rosterGeneration,[c.from]:{from:c.from,to:c.to,sourcePeriod:previous.length?periodLabel(previous[0].date):null,generatedAt:now.toISOString(),added:(old?.added||0)+added,unfilled}};
 coverLeaveDuties(s,now);
}
function publishCurrentRoster(s:State,p:Row,now:Date){
 const c=requireCurrentPeriod(p,now);
 const generated=s.settings.rosterGeneration?.[c.from];
 if(generated?.unfilled?.length||coverLeaveDuties(s,now).length)throw Error('Resolve uncovered duties before publishing this period. Review automatic allocation warnings.');
 const list=s.assignments.filter(a=>a.date>=c.from&&a.date<=c.to&&a.status==='Draft'&&effectiveDuty(s,a));
 if(!list.length)throw Error('There are no draft duties to publish in the current period.');
 for(const a of list)checkAssignment(a,s,s.assignments);
 for(const a of list)a.status='Published';
 for(const a of s.assignments.filter(a=>a.date>=c.from&&a.date<=c.to&&a.status==='Draft'&&onApprovedLeave(s,a.person,a.date))){if(s.assignments.some(b=>b.replacesAssignment===a.id&&b.status==='Published'&&effectiveDuty(s,b)))a.status='Published';}
 s.settings.rosterPublished={...s.settings.rosterPublished,[c.from]:{from:c.from,to:c.to,publishedAt:now.toISOString()}};
}
