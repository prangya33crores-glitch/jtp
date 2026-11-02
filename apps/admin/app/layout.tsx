import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = {title:'JTP Command | Roster & Payroll', description:'Personnel, duty rosters, leave and payroll in one workspace.'};
export default function RootLayout({children}:{children:React.ReactNode}) {return <html lang="en"><body>{children}</body></html>}
