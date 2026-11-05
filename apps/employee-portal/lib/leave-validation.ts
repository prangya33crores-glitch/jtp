type LeaveRecord={from:string;to:string;status:string;type?:string};
export function leaveDateError(leaves:LeaveRecord[],from:string,to:string){
 if(!from||!to)return '';
 if(to<from)return 'To date must be on or after From date.';
 const conflict=leaves.find(l=>['Pending','Approved'].includes(l.status)&&from<=l.to&&to>=l.from);
 if(!conflict)return '';
 return `You already have ${conflict.status.toLowerCase()} leave from ${conflict.from} to ${conflict.to}. These dates overlap your request. Please choose different dates.`;
}
