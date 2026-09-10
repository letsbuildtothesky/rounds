/** Compiled React fixture only. Never loads/rehosts the original HTML.
 * Browser context is ephemeral; HTTP/Auth data are explicitly synthetic.
 * Real restricted SQL/controller evidence is in manual-intake.postgis.ts. */
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {pathToFileURL,fileURLToPath} from 'node:url';
const {chromium}=await import(pathToFileURL(process.env.ROUNDS_PLAYWRIGHT_MODULE).href);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const context=await browser.newContext({viewport:{width:1365,height:1000}});
const page=await context.newPage(),errors=[];
page.on('pageerror',e=>errors.push(e.message));
const folder=new URL('../specs/build-v2.3/generated/manual-intake-browser/',import.meta.url);
await mkdir(folder,{recursive:true});
const results=[];
try{
  await page.goto('http://127.0.0.1:3024/?deliveries=1&intake-test=1');
  const opener=page.getByRole('button',{name:'Add delivery',exact:true});
  const dialog=page.getByRole('dialog',{name:'Add delivery',exact:true});
  await opener.click();
  const recipient=dialog.locator('input[name=recipient]');
  await recipient.waitFor();
  await page.waitForFunction(()=>!document.querySelector('input[name=recipient]').matches(':disabled'));
  await recipient.fill('Johannes · Browser test');
  await dialog.locator('textarea[name=address]').fill('  Synthetic address · ไม่ใช่ลูกค้าจริง  ');
  await dialog.locator('input[name=products]').fill('2 × Flowers + Cake x3');
  await dialog.getByText('Phone & delivery instructions',{exact:true}).click();
  await dialog.locator('input[name=phone]').fill('+66000000000');
  await dialog.locator('input[name=notes]').fill('Keep upright · test only');
  await dialog.getByRole('checkbox',{name:'Ready for pickup'}).check();
  await dialog.getByRole('heading',{name:'Add delivery'}).click();
  await page.waitForFunction(()=>document.querySelector('.add-autofill-message').textContent.startsWith('Draft saved.'));
  assert(await dialog.getByRole('button',{name:'Create delivery',exact:true}).isDisabled());
  results.push('source field edits and background draft save; final creation remains disabled');
  await page.keyboard.press('Escape');
  assert.equal(await dialog.count(),0);
  assert.equal(await opener.evaluate(el=>el===document.activeElement),true);
  await opener.click();
  await page.waitForFunction(()=>!document.querySelector('input[name=recipient]').matches(':disabled'));
  assert.equal(await recipient.inputValue(),'Johannes · Browser test');
  assert.equal(await dialog.locator('input[name=products]').inputValue(),'2 × Flowers + Cake x3');
  results.push('Escape closes, returns focus and retains exact edits on reopen');
  await page.reload();
  await opener.click();
  await page.waitForFunction(()=>!document.querySelector('input[name=recipient]').matches(':disabled'));
  assert.equal(await recipient.inputValue(),'Johannes · Browser test');
  assert.equal(await dialog.locator('input[name=products]').inputValue(),'2 × Flowers + Cake x3');
  assert.equal(await dialog.locator('input[name=notes]').inputValue(),'Keep upright · test only');
  assert(await dialog.getByRole('checkbox',{name:'Ready for pickup'}).isChecked());
  results.push('same-login tab reload recovers fields after fresh authorized context/revision read');
  // New edits and closing while an older request is in flight.
  await page.route('**/v1/commands/SaveDeliveryDraft',async route=>{await new Promise(r=>setTimeout(r,200));await route.continue();});
  await recipient.fill('Johannes · Slow save test');
  await dialog.locator('input[name=products]').fill('4 × Flowers');
  await dialog.getByRole('button',{name:'Cancel',exact:true}).click();
  await page.waitForFunction(()=>document.querySelector('.add-autofill-message').textContent.startsWith('Draft saved.'));
  await opener.click();await page.waitForFunction(()=>!document.querySelector('input[name=recipient]').matches(':disabled'));
  assert.equal(await dialog.locator('input[name=products]').inputValue(),'4 × Flowers');
  await page.unroute('**/v1/commands/SaveDeliveryDraft');
  results.push('close during a delayed save flushes newer edits only after the original receipt');
  for(const width of [1365,390]){
    await page.setViewportSize({width,height:1000});
    await dialog.evaluate(el=>el.scrollTop=0);
    const bounds=await dialog.boundingBox();assert(bounds&&bounds.x>=0&&bounds.x+bounds.width<=width+1);
    const metrics=await dialog.evaluate(el=>({width:el.getBoundingClientRect().width,overflow:el.scrollWidth>el.clientWidth,
      headerPadding:getComputedStyle(el.querySelector('.dialog-header')).padding,fieldGap:getComputedStyle(el.querySelector('.add-form-fields')).gap}));
    assert.equal(metrics.overflow,false);assert.equal(metrics.fieldGap,'18px');
    await page.screenshot({path:fileURLToPath(new URL(`form-${width}-top.png`,folder))});
    await dialog.getByRole('button',{name:'Create delivery',exact:true}).scrollIntoViewIfNeeded();
    await page.screenshot({path:fileURLToPath(new URL(`form-${width}-bottom.png`,folder))});
    results.push({width,metrics});
  }
  await dialog.getByRole('button',{name:'Cancel',exact:true}).click();assert.equal(await dialog.count(),0);
  const evidence=await (await fetch('http://127.0.0.1:3024/test-evidence')).json();
  assert(evidence.intakePosts>0);assert.deepEqual(errors,[]);
  await writeFile(new URL('result.json',folder),JSON.stringify({at:new Date().toISOString(),synthetic:true,sourcePixelParity:'NOT_RUN',results,errors,evidence},null,2));
  console.log(JSON.stringify({pass:true,results,errors}));
}finally{await context.close();await browser.close();}
