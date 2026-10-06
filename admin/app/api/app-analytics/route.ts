import {cookies} from "next/headers";
export async function GET(request:Request){
 const token=(await cookies()).get("ur_admin_session")?.value;
 if(!token)return Response.json({error:"unauthorized"},{status:401});
 const days=new URL(request.url).searchParams.get("days")??"30";
 if(!["0","1","7","30","90"].includes(days))return Response.json({error:"invalid_period"},{status:400});
 const base=process.env.UR_ANALYTICS_URL??"https://yqvcoomjunwokyxwofvt.supabase.co/functions/v1/app-analytics";
 if(new URL(base).protocol!=="https:")return Response.json({error:"configuration"},{status:503});
 try{const r=await fetch(`${base}/summary?days=${days}`,{headers:{authorization:`Bearer ${token}`},cache:"no-store",signal:AbortSignal.timeout(10000)});return new Response(await r.text(),{status:r.status,headers:{"content-type":"application/json","cache-control":"no-store"}});}catch{return Response.json({error:"unavailable"},{status:503});}
}
