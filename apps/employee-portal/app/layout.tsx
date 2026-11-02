import type {Metadata} from 'next';
import './globals.css';
export const metadata:Metadata={title:'JTP Employee Portal',description:'Secure personal duty roster, leave and salary information.',robots:{index:false,follow:false}};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
