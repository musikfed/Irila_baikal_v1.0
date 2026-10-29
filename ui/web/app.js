'use strict';
/* Irina Shell UI, v0.3. All camera frames remain inside the browser unless the user joins an external call. */
(() => {
  const $ = (sel, root=document) => root.querySelector(sel);
  const windows = $('#windows');
  const launcher = $('#launcher');
  const quick = $('#quick-settings');
  const bubble = $('#camera-bubble');
  const video = $('#selfie-video');
  const placeholder = $('#camera-placeholder');
  let cameraStream = null;
  let windowZ = 30;
  let toastTimeout;
  let cameraBusy = false;

  function toast(message) {
    const el = $('#toast'); el.textContent = message; el.classList.add('show');
    clearTimeout(toastTimeout); toastTimeout = setTimeout(() => el.classList.remove('show'), 4600);
  }
  function setTheme(name) {
    if (!['lake','forest','night'].includes(name)) return;
    document.body.dataset.theme = name;
    try { localStorage.setItem('irina-theme',name); } catch (_) { /* ephemeral mode */ }
    document.querySelectorAll('[data-theme]').forEach(el => {
      if (el.matches('button')) el.setAttribute('aria-pressed', String(el.dataset.theme === name));
    });
  }
  try { setTheme(localStorage.getItem('irina-theme') || 'lake'); } catch (_) { setTheme('lake'); }
  function closePopovers() { launcher.hidden = true; quick.hidden = true; $('#start-button').setAttribute('aria-expanded','false'); $('#quick-toggle').setAttribute('aria-expanded','false'); }
  $('#start-button').addEventListener('click',e => { const next = launcher.hidden; closePopovers(); launcher.hidden=!next; e.currentTarget.setAttribute('aria-expanded',String(next)); });
  $('#quick-toggle').addEventListener('click',e => { const next = quick.hidden; closePopovers(); quick.hidden=!next; e.currentTarget.setAttribute('aria-expanded',String(next)); });
  document.addEventListener('pointerdown', e => { if (!e.target.closest('#launcher,#quick-settings,#start-button,#quick-toggle')) closePopovers(); });
  document.addEventListener('keydown',e=> { if(e.key==='Escape') closePopovers(); if(e.ctrlKey && e.key===' ') {e.preventDefault(); $('#start-button').click();} });

  const templates = {
    ai: {title:'✦ Ирина · локальный ИИ', html:`<h2>Поговорим?</h2><p>Локальная модель Ollama отвечает через Python-сервис на твоём компьютере. Если Ollama не установлена, будет подсказка.</p><div class="chat-history" id="chat-history"><div class="chat-message">Привет! Я Ирина. Готова помочь, когда локальная модель будет запущена.</div></div><form id="chat-form" class="chat-form"><input class="field" id="chat-prompt" maxlength="4000" placeholder="Напиши Ирине..." required aria-label="Сообщение Ирине"><button class="primary-button" type="submit">Отправить</button></form><p class="hint">Диалог в этой версии не сохраняется. Для ответа нужен локальный Ollama с моделью Qwen.</p>`},
    camera:{title:'◉ Селфи · круглая камера',html:`<h2>Круглое окно камеры</h2><p>Камера выводится поверх рабочего стола в круглой рамке. Окно можно перетаскивать. Селфи сохраняется в PNG на твоём устройстве.</p><div class="button-row"><button type="button" class="primary-button" data-cmd="camera-start">Включить камеру</button><button type="button" class="glass-button" data-cmd="camera-shot">Сделать селфи</button><button type="button" class="glass-button" data-cmd="camera-stop">Отключить камеру</button></div><p class="hint">Разрешение запрашивается браузером. Видео никуда не загружается.</p>`},
    video:{title:'▣ Связь · ВКС',html:`<h2>Видеосвязь</h2><p>Общайся по видео. Перед звонком можно включить собственное круглое видеоокно для проверки камеры.</p><div class="button-row"><button type="button" class="glass-button" data-cmd="camera-start">◉ Проверить селфи-камеру</button><button type="button" class="glass-button" data-cmd="camera-stop">Остановить камеру</button></div><label for="call-room">Название комнаты для встречи</label><input id="call-room" class="field" maxlength="80" autocomplete="off" placeholder="Название комнаты"><button type="button" class="primary-button" data-cmd="join-call">Начать ВКС ↗</button><div class="external-notice">Пока используется внешний сервис Jitsi Meet (meet.jit.si): откроется новая вкладка. Камера и микрофон в звонке разрешаются отдельно в браузере. Для собственного сервера ВКС потребуется отдельный этап разработки.</div><p class="status-line" id="call-status"></p>`},
    internet:{title:'◎ Интернет',html:`<h2>Открыть сайт</h2><p>Введи адрес сайта. Он откроется в новой вкладке браузера.</p><form id="browser-form"><label for="browser-url">Адрес URL</label><input class="field" id="browser-url" type="url" placeholder="https://example.org" value="https://" required><button class="primary-button" type="submit">Открыть ↗</button></form><p class="hint">Hrag-пересказ страниц будет добавлен в следующем этапе.</p>`},
    files:{title:'▤ Мои файлы',html:`<h2>Локальные файлы</h2><p>В этой демонстрационной оболочке можно выбрать файлы для просмотра имён и размеров. Данные не отправляются на сервер.</p><label for="file-picker">Выбрать файлы</label><input class="field" id="file-picker" type="file" multiple><ul id="file-list" class="file-list"></ul><p class="hint">Полноценный файловый менеджер будет подключён в Ubuntu-версии.</p>`},
    settings:{title:'⚙ Параметры',html:`<h2>Оформление Ирины</h2><p>Окна в сине-зелёной гамме, всплывающее меню, собственная панель задач и круглая камера.</p><h3>Цветовая тема</h3><div class="button-row"><button class="glass-button" type="button" data-theme="lake">🌊 Байкал</button><button class="glass-button" type="button" data-theme="forest">🌿 Тайга</button><button class="glass-button" type="button" data-theme="night">☾ Ночь</button></div><div class="card-row"><div class="mini-card"><strong>Acer</strong><small>Ryzen 5 3500U · Vega 8</small></div><div class="mini-card"><strong>20 ГБ</strong><small>ОЗУ · по заявленному профилю</small></div></div><p class="hint" style="margin-top:16px">Обои — оригинальная стилизованная иллюстрация Байкала. Настоящую фотографию добавим после выбора изображения с подходящей лицензией.</p>`}
    ,
    suite: {title:'▤ Офис и графика',html:[
      '<h2>Бесплатные программы</h2><p>Выбирай программу. На Ubuntu она запускается, если установлена. В Windows это предварительный просмотр меню.</p>',
      '<h3>LibreOffice</h3><div class="native-grid">',
      '<button type="button" data-launch="writer">▤ Writer · Текстовые документы</button>',
      '<button type="button" data-launch="calc">▤ Calc · Таблицы</button>',
      '<button type="button" data-launch="impress">▤ Impress · Презентации</button>',
      '<button type="button" data-launch="draw">▤ Draw · Рисунки и схемы</button>',
      '<button type="button" data-launch="base">▤ Base · Базы данных</button>',
      '</div><h3>Графика</h3><div class="native-grid">',
      '<button type="button" data-launch="gimp">◫ GIMP · Редактор фото</button>',
      '<button type="button" data-launch="inkscape">◇ Inkscape · Векторная графика</button>',
      '</div><p class="status-line native-status" aria-live="polite"></p>'
    ].join('')},
    mail: {title:'Ирина Байкал · Почта',html:[
      '<h2>Универсальная почта</h2>',
      '<p>Thunderbird поддерживает несколько почтовых аккаунтов с IMAP/POP3/SMTP. Учётные данные хранятся в профиле Thunderbird, не в Irina Shell.</p>',
      '<button type="button" class="primary-button" data-launch="mail">✉ Открыть почту</button>',
      '<p class="status-line native-status" aria-live="polite"></p>'
    ].join('')},
    sip: {title:'Ирина Байкал · Телефон',html:[
      '<h2>Цифровая телефония SIP</h2>',
      '<p>Linphone — бесплатный SIP-клиент. Для звонков нужен SIP-аккаунт от провайдера или собственная АТС. Asterisk — сервер, а не обязательный клиент.</p>',
      '<button type="button" class="primary-button" data-launch="sip">☎ Открыть SIP-клиент</button>',
      '<p class="status-line native-status" aria-live="polite"></p>'
    ].join('')},
    games: {title:'Ирина Байкал · Игры',html:[
      '<h2>Мини-игры без рекламы</h2><p>Небольшие свободные игры для отдыха. Устанавливаются отдельно в Ubuntu.</p>',
      '<div class="native-grid"><button type="button" data-launch="solitaire">♠ Пасьянс</button>',
      '<button type="button" data-launch="mines">▧ Сапёр</button>',
      '<button type="button" data-launch="mahjongg">▦ Маджонг</button></div>',
      '<p class="status-line native-status" aria-live="polite"></p>'
    ].join('')}
  };
  function openApp(id) {
    const t = templates[id]; if (!t) return;
    closePopovers();
    if (id === 'camera') setCameraVisible(true);
    const current = document.querySelector(`.app-window[data-app-id="${id}"]`);
    if (current) {current.style.zIndex=String(++windowZ);return;}
    const el=document.createElement('section');el.className='app-window';el.dataset.appId=id;el.setAttribute('role','dialog');el.setAttribute('aria-label',t.title);
    const title=document.createElement('div');title.className='window-top';title.innerHTML='<span class="window-title"></span><div class="window-actions"><button type="button" class="window-close" title="Закрыть окно" aria-label="Закрыть окно">×</button></div>';
    $('.window-title',title).textContent=t.title;
    const body=document.createElement('div');body.className='window-body';body.innerHTML=t.html;
    el.append(title,body);el.style.zIndex=String(++windowZ);windows.appendChild(el);
    $('.window-close',el).addEventListener('click',()=>el.remove());
    el.addEventListener('pointerdown',()=>{el.style.zIndex=String(++windowZ);});
    enableDrag(el,title);
    if(id==='video') $('#call-room',el).value=`IrinaBaikal-${randomToken()}`;
    if(id==='ai') attachChat(el);
    if(id==='internet') attachBrowser(el);
    if(id==='files') attachFilePicker(el);
    window.IrinaI18n?.apply(el);
  }
  function enableDrag(target,handle) {
    let start=null;
    handle.addEventListener('pointerdown', e => {
      if(e.button!==0 || e.target.closest('button') || matchMedia('(max-width: 760px)').matches)return;
      start={x:e.clientX,y:e.clientY,left:target.getBoundingClientRect().left,top:target.getBoundingClientRect().top}; handle.setPointerCapture(e.pointerId);
    });
    handle.addEventListener('pointermove',e => {if(!start)return;target.style.left=Math.max(4,Math.min(innerWidth-target.offsetWidth-4,start.left+e.clientX-start.x))+'px';target.style.top=Math.max(65,Math.min(innerHeight-100,start.top+e.clientY-start.y))+'px';});
    for(const name of ['pointerup','pointercancel','lostpointercapture'])handle.addEventListener(name,()=>{start=null;});
  }
  function randomToken(){const a=new Uint8Array(6);crypto.getRandomValues(a);return [...a].map(x=>x.toString(16).padStart(2,'0')).join('');}
  async function startCamera() {
    setCameraVisible(true);
    if(cameraStream) {toast('Камера уже включена');return;}
    if(cameraBusy)return; cameraBusy=true;
    try {
      if(!navigator.mediaDevices?.getUserMedia) throw new Error('Камера доступна только через localhost или HTTPS и в совместимом браузере.');
      cameraStream=await navigator.mediaDevices.getUserMedia({video:{facingMode:'user',width:{ideal:1280}},audio:false});
      video.srcObject=cameraStream;await video.play();placeholder.hidden=true;$('#camera-toggle').textContent='■';$('#camera-toggle').title='Выключить камеру';$('#camera-shot').disabled=false;
      toast('Камера активна. Кадры остаются на устройстве.');
    } catch(e){toast('Камера недоступна: '+(e.message||'проверь разрешение браузера'));stopCamera();}
    finally{cameraBusy=false;}
  }
  function setCameraVisible(visible){bubble.hidden=!visible;if(!visible)stopCamera();try{localStorage.setItem('irina-camera-visible',visible?'1':'0');}catch(_){}}
  try{setCameraVisible(localStorage.getItem('irina-camera-visible')!=='0');}catch(_){setCameraVisible(true);}
  function stopCamera(){if(cameraStream){cameraStream.getTracks().forEach(track=>track.stop());cameraStream=null;} video.pause();video.srcObject=null;placeholder.hidden=false;$('#camera-toggle').textContent='▶';$('#camera-toggle').title='Включить камеру';$('#camera-shot').disabled=true;}
  function takeSelfie(){
    if(!cameraStream||!video.videoWidth){toast('Сначала включи камеру');return;}
    const c=document.createElement('canvas');c.width=c.height=700;const ctx=c.getContext('2d');ctx.clearRect(0,0,700,700);ctx.beginPath();ctx.arc(350,350,350,0,Math.PI*2);ctx.clip();
    const sw=video.videoWidth,sh=video.videoHeight,size=Math.min(sw,sh),sx=(sw-size)/2,sy=(sh-size)/2;
    ctx.translate(700,0);ctx.scale(-1,1);ctx.drawImage(video,sx,sy,size,size,0,0,700,700);
    c.toBlob(blob=>{if(!blob)return;const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='IrinaBaikal-selfie-'+new Date().toISOString().slice(0,10)+'.png';a.click();setTimeout(()=>URL.revokeObjectURL(url),60000);toast('Круглое селфи сохранено в PNG');},'image/png');
  }
  function joinCall(root){const input=$('#call-room',root);const name=input?.value.trim()||'';const status=$('#call-status',root);if(!/^[\p{L}\p{N}_-]{6,80}$/u.test(name)){status.textContent='Комната: минимум 6 символов, буквы, цифры, _ или -';return;}const url='https://meet.jit.si/'+encodeURIComponent(name);const tab=window.open(url,'_blank','noopener,noreferrer');status.textContent='Встреча открывается во внешнем Jitsi Meet. Разреши камеру и микрофон там, если хочешь.';if(tab===null)status.textContent+=' Если вкладка не появилась, разреши всплывающие окна для localhost.';}
  function attachChat(el){const form=$('#chat-form',el),history=$('#chat-history',el),input=$('#chat-prompt',el);form.addEventListener('submit',async e=>{e.preventDefault();const message=input.value.trim();if(!message)return;input.value='';const mine=document.createElement('div');mine.className='chat-message mine';mine.textContent=message;history.appendChild(mine);const response=document.createElement('div');response.className='chat-message';response.textContent='Ирина думает…';history.appendChild(response);history.scrollTop=history.scrollHeight;const submit=form.querySelector('[type="submit"]');submit.disabled=true;try{const ctrl=new AbortController();const timer=setTimeout(()=>ctrl.abort(),90000);let r;try{r=await fetch('/api/ai',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message}),signal:ctrl.signal});}finally{clearTimeout(timer);}const data=await r.json();if(!r.ok)throw Error(data.error||'Ошибка сервера');response.textContent=data.reply||'Нет ответа';}catch(err){response.classList.add('error');response.textContent='Офлайн-модель недоступна: '+err.message+'. Установи Ollama и загрузи модель qwen3:1.7b.';}finally{submit.disabled=false;history.scrollTop=history.scrollHeight;}});}
  function attachBrowser(el){$('#browser-form',el).addEventListener('submit',e=>{e.preventDefault();try{const url=new URL($('#browser-url',el).value.trim());if(!['https:','http:'].includes(url.protocol))throw Error('Нужна ссылка http:// или https://');window.open(url.href,'_blank','noopener,noreferrer');}catch(err){toast(err.message);}});}
  function attachFilePicker(el){$('#file-picker',el).addEventListener('change',e=>{const ul=$('#file-list',el);ul.replaceChildren();for(const f of e.target.files){const li=document.createElement('li');li.textContent=`${f.name} · ${(f.size/1024).toFixed(1)} КБ`;ul.appendChild(li);}});}
  document.addEventListener('click',e=>{
    const theme=e.target.closest('button[data-theme]');if(theme){setTheme(theme.dataset.theme);return;}
    const app=e.target.closest('button[data-app]');if(app){openApp(app.dataset.app);return;}
    const native=e.target.closest('button[data-launch]');
    if(native){void launchNative(native);return;}
    const cmd=e.target.closest('button[data-cmd]');if(!cmd)return;
    if(cmd.dataset.cmd==='camera-visibility')setCameraVisible(bubble.hidden);
    if(cmd.dataset.cmd==='camera-show')setCameraVisible(true);
    if(cmd.dataset.cmd==='camera-hide')setCameraVisible(false);
    if(cmd.dataset.cmd==='camera-start')void startCamera();if(cmd.dataset.cmd==='camera-shot')takeSelfie();if(cmd.dataset.cmd==='camera-stop')stopCamera();if(cmd.dataset.cmd==='join-call')joinCall(cmd.closest('.app-window'));
  });
  $('#camera-toggle').addEventListener('click',()=>cameraStream?stopCamera():startCamera());
  $('#camera-shot').addEventListener('click',takeSelfie);
  $('#camera-close').addEventListener('click',()=>setCameraVisible(false));
  // Camera can be moved using its small drag handle without breaking camera buttons.
  const drag=$('#camera-drag');let bubbleStart=null;
  drag.addEventListener('pointerdown',e=>{bubbleStart={x:e.clientX,y:e.clientY,left:bubble.getBoundingClientRect().left,top:bubble.getBoundingClientRect().top};drag.setPointerCapture(e.pointerId);});
  drag.addEventListener('pointermove',e=>{if(!bubbleStart)return;bubble.style.left=Math.max(0,Math.min(innerWidth-bubble.offsetWidth,bubbleStart.left+e.clientX-bubbleStart.x))+'px';bubble.style.top=Math.max(65,Math.min(innerHeight-bubble.offsetHeight-70,bubbleStart.top+e.clientY-bubbleStart.y))+'px';bubble.style.right='auto';bubble.style.bottom='auto';});
  for(const name of ['pointerup','pointercancel','lostpointercapture'])drag.addEventListener(name,()=>bubbleStart=null);
  const clock=()=>{const now=new Date();const locale=window.IrinaI18n?.getLanguage()==='en'?'en-US':'ru-RU';$('#clock-time').textContent=new Intl.DateTimeFormat(locale,{hour:'2-digit',minute:'2-digit'}).format(now);$('#clock-date').textContent=new Intl.DateTimeFormat(locale,{day:'numeric',month:'short'}).format(now);};clock();setInterval(clock,15000);
  async function launchNative(button){
    const id=button.dataset.launch;
    const status=button.closest('.app-window')?.querySelector('.native-status');
    button.disabled=true;
    try{
      const response=await fetch('/api/launch',{
        method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({app:id})
      });
      const result=await response.json();
      if(!response.ok)throw Error(result.error||'Application not available');
      const message=window.IrinaI18n?.getLanguage()==='en'?'Application launched':'Программа запущена';
      if(status)status.textContent=message;
      toast(message);
    }catch(error){
      const message=error.message||'Application unavailable';
      if(status)status.textContent=message;
      toast(message);
    }finally{button.disabled=false;}
  }
  $('#language-toggle').addEventListener('click',()=>{
    const api=window.IrinaI18n;
    if(api)api.setLanguage(api.getLanguage()==='ru'?'en':'ru');
    clock();
  });
  $('#keyboard-help').addEventListener('click',()=>{
    openApp('settings');
    toast(window.IrinaI18n?.getLanguage()==='en'?
      'Keyboard: Windows Win+Space; Ubuntu XFCE/X11 Alt+Shift':
      'Раскладка: Windows Win+Пробел; Ubuntu XFCE/X11 Alt+Shift');
  });
  window.IrinaI18n?.apply();
  window.addEventListener('beforeunload',stopCamera);
})();
