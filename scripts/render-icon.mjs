import { chromium } from 'playwright';
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 512, height: 512 } });
await p.goto('file:///Users/mirela.mei/Desktop/centavoo/public/pwa-icon.svg');
await p.screenshot({ path: '/tmp/centavoo-icon.png' });
await b.close();
console.log('ok');
