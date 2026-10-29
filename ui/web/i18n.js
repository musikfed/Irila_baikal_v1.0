/* Irina Shell v0.5 localization. UI language only; keyboard layouts are configured by XKB. */
'use strict';
window.IrinaI18n = (() => {
  const ruToEn = {
    'Локальный рабочий стол':'Local desktop',
    'ЛИЧНАЯ ОПЕРАЦИОННАЯ СИСТЕМА':'PERSONAL OPERATING SYSTEM',
    'Технологии с характером Байкала.':'Technology inspired by Lake Baikal.',
    'Твой мир. Твой интеллект. Твоя связь.':'Your world. Your intelligence. Your connection.',
    '✦ Общение с Ириной':'✦ Chat with Irina',
    '◉ Видеосвязь':'◉ Video calls',
    'Селфи':'Selfie', 'ВКС':'Video call', 'Файлы':'Files', 'Параметры':'Settings',
    'Приложения рабочего стола':'Desktop applications','Рабочий стол':'Desktop',
    'Главное меню · 1.0':'Main menu · 1.0','Меню приложений':'Application menu',
    'ИИ Ирина':'AI Irina','Камера':'Camera','Видеосвязь':'Video calls',
    'Интернет':'Internet','Настройки':'Settings','Программы':'Applications',
    'Офис и графика':'Office & graphics','Почта':'Mail','SIP-телефон':'SIP phone',
    'Мини-игры':'Mini games','Открытые окна':'Open windows','Быстрые настройки':'Quick settings',
    'Оформление системы':'Appearance',
    '◉ Круглая камера':'◉ Round camera','⚙ Все параметры':'⚙ All settings',
    '◉ Показать / скрыть круг':'◉ Show / hide camera circle',
    'Язык интерфейса':'Interface language',
    'Язык интерфейса: RU / EN':'Interface language: RU / EN',
    'Ирина Байкал':'Irina Baikal',
    '◉ Селфи':'◉ Selfie',
    'Твой мир. Твой интеллект. Твоя связь.':'Your world. Your intelligence. Your connection.',
    'Раскладка клавиатуры':'Keyboard layout',
    'Windows: Win + Пробел · Ubuntu XFCE/X11: Alt + Shift':'Windows: Win + Space · Ubuntu XFCE/X11: Alt + Shift',
    'Круглое окно селфи':'Round selfie window','Камера выключена':'Camera is off',
    'Предпросмотр веб-камеры':'Webcam preview','Перемещать круглое окно':'Move round window',
    'Включить камеру':'Turn camera on','Выключить камеру':'Turn camera off',
    'Сделать селфи':'Take selfie','Закрыть круглую камеру':'Close camera circle',
    'Закрыть':'Close','Открыть меню':'Open menu','Панель задач':'Taskbar',
    'Сине-зелёная тема':'Blue-green theme','Зелёная тема':'Green theme','Ночная тема':'Night theme',
    '✦ Ирина · локальный ИИ':'✦ Irina · local AI',
    'Поговорим?':'Shall we talk?',
    'Локальная модель Ollama отвечает через Python-сервис на твоём компьютере. Если Ollama не установлена, будет подсказка.':'Local Ollama runs via a Python service on your computer. If it is not installed, you will see a hint.',
    'Привет! Я Ирина. Готова помочь, когда локальная модель будет запущена.':'Hello! I am Irina. Ready to help once the local model starts.',
    'Отправить':'Send',
    'Диалог в этой версии не сохраняется. Для ответа нужен локальный Ollama с моделью Qwen.':'Chat is not saved in this version. A local Ollama Qwen model is required.',
    '◉ Селфи · круглая камера':'◉ Selfie · round camera',
    'Камера выводится поверх рабочего стола в круглой рамке. Окно можно перетаскивать. Селфи сохраняется в PNG на твоём устройстве.':'The camera floats above your desktop in a draggable circle. Selfies are saved as PNG on your device.',
    'Отключить камеру':'Turn camera off',
    'Разрешение запрашивается браузером. Видео никуда не загружается.':'Camera permission is requested by the browser. Video is not uploaded.',
    '▣ Связь · ВКС':'▣ Communication · video calls',
    'Общайся по видео. Перед звонком можно включить собственное круглое видеоокно для проверки камеры.':'Make video calls. You can enable the round camera preview before joining.',
    '◉ Проверить селфи-камеру':'◉ Test selfie camera','Остановить камеру':'Stop camera',
    'Название комнаты для встречи':'Meeting room name','Начать ВКС ↗':'Start video call ↗',
    'Пока используется внешний сервис Jitsi Meet (meet.jit.si): откроется новая вкладка. Камера и микрофон в звонке разрешаются отдельно в браузере. Для собственного сервера ВКС потребуется отдельный этап разработки.':'Video meetings currently use external Jitsi Meet (meet.jit.si) in a new tab. Camera and microphone permissions are requested separately. A self-hosted service is future work.',
    '◎ Интернет':'◎ Internet','Открыть сайт':'Open website',
    'Введи адрес сайта. Он откроется в новой вкладке браузера.':'Enter a website address to open it in a new browser tab.',
    'Адрес URL':'Website URL','Открыть ↗':'Open ↗',
    'Hrag-пересказ страниц будет добавлен в следующем этапе.':'HRAG page summaries are planned for a later version.',
    '▤ Мои файлы':'▤ My files','Локальные файлы':'Local files',
    'В этой демонстрационной оболочке можно выбрать файлы для просмотра имён и размеров. Данные не отправляются на сервер.':'Select local files to inspect filenames and sizes in this demo. Files are not uploaded.',
    'Выбрать файлы':'Select files',
    'Полноценный файловый менеджер будет подключён в Ubuntu-версии.':'A native file manager will be added in the Ubuntu version.',
    '⚙ Параметры':'⚙ Settings','Оформление Ирины':'Irina appearance',
    'Окна в сине-зелёной гамме, всплывающее меню, собственная панель задач и круглая камера.':'Blue-green windows, a pop-up menu, taskbar and round camera.',
    'Цветовая тема':'Color theme','🌊 Байкал':'🌊 Baikal','🌿 Тайга':'🌿 Taiga','☾ Ночь':'☾ Night',
    'ОЗУ · по заявленному профилю':'RAM · owner-reported',
    'Обои — оригинальная стилизованная иллюстрация Байкала. Настоящую фотографию добавим после выбора изображения с подходящей лицензией.':'Wallpaper uses original vector art inspired by Lake Baikal. A licensed photograph may be added later.',
    '▤ Офис и графика':'▤ Office & graphics',
    'Бесплатные программы':'Free applications',
    'Выбирай программу. На Ubuntu она запускается, если установлена. В Windows это предварительный просмотр меню.':'Choose an app. On Ubuntu it launches when installed. On Windows this is a menu preview.',
    'Текстовые документы':'Text documents','Таблицы':'Spreadsheets','Презентации':'Presentations',
    'Рисунки и схемы':'Drawings & diagrams','Базы данных':'Databases',
    'Редактор фото':'Photo editor','Векторная графика':'Vector graphics',
    'Ирина Байкал · Почта':'Irina Baikal · Mail',
    'Универсальная почта':'Universal mail',
    'Thunderbird поддерживает несколько почтовых аккаунтов с IMAP/POP3/SMTP. Учётные данные хранятся в профиле Thunderbird, не в Irina Shell.':'Thunderbird supports multiple IMAP/POP3/SMTP accounts. Credentials are stored in its profile, never in Irina Shell.',
    'Открыть почту':'Open mail',
    'Ирина Байкал · Телефон':'Irina Baikal · Phone',
    'Цифровая телефония SIP':'SIP digital telephony',
    'Linphone — бесплатный SIP-клиент. Для звонков нужен SIP-аккаунт от провайдера или собственная АТС. Asterisk — сервер, а не обязательный клиент.':'Linphone is a free SIP client. Calls require a SIP account or a PBX. Asterisk is a server and not required for client calls.',
    'Открыть SIP-клиент':'Open SIP client',
    'Ирина Байкал · Игры':'Irina Baikal · Games',
    'Мини-игры без рекламы':'Ad-free mini games',
    'Небольшие свободные игры для отдыха. Устанавливаются отдельно в Ubuntu.':'Small free games, installed separately on Ubuntu.',
    'Пасьянс':'Solitaire','Сапёр':'Mines','Маджонг':'Mahjongg',
    'Показать круг':'Show circle','Скрыть круг':'Hide circle',
    'Плавающий круг камеры':'Floating camera circle',
    'При старте показывать круг с выключенной камерой. Крестик скрывает его, но никогда не включает видеозапись.':'Show the circle at startup with the camera turned off. The close button hides it and never starts video capture.',
    'Включить / выключить круг':'Show / hide circle',
    'Клавиатура':'Keyboard',
    'Переключение языка интерфейса отдельно от раскладки клавиатуры.':'Interface language is separate from keyboard layout.',
    '▤ Writer · Текстовые документы':'▤ Writer · Text documents',
    '▤ Calc · Таблицы':'▤ Calc · Spreadsheets',
    '▤ Impress · Презентации':'▤ Impress · Presentations',
    '▤ Draw · Рисунки и схемы':'▤ Draw · Drawings & diagrams',
    '▤ Base · Базы данных':'▤ Base · Databases',
    '▤ Math · Формулы':'▤ Math · Formulas',
    '◫ GIMP · Редактор фото':'◫ GIMP · Photo editor',
    '◇ Inkscape · Векторная графика':'◇ Inkscape · Vector graphics',
    '✉ Открыть почту':'✉ Open mail',
    '☎ Открыть SIP-клиент':'☎ Open SIP client',
    '♠ Пасьянс':'♠ Solitaire','▧ Сапёр':'▧ Mines','▦ Маджонг':'▦ Mahjongg',
    'Ирина думает…':'Irina is thinking…',
    'Напиши Ирине...':'Message Irina...',
    'Название комнаты':'Room name',
    'https://example.org':'https://example.org',
    'Открыть меню':'Open menu',
    'Локальные приложения доступны только в Linux с установленными пакетами.':'Native apps require Linux and installed packages.'
  };
  let lang='ru';
  try { lang=localStorage.getItem('irina-language')==='en' ? 'en':'ru'; }catch(_){}
  const originals=new WeakMap();
  const attributes=new WeakMap();
  function translate(value){return lang==='en' ? (ruToEn[value] || value) : value;}
  function apply(root=document){
    const walk=document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    let node; const nodes=[];
    while((node=walk.nextNode()))nodes.push(node);
    for(const text of nodes){
      if(text.parentElement?.closest('script,style,svg'))continue;
      let base=originals.get(text);
      if(base===undefined){base=text.nodeValue;originals.set(text,base);}
      const trimmed=base.trim();
      if(trimmed && ruToEn[trimmed]){
        const start=base.indexOf(trimmed);
        text.nodeValue=base.slice(0,start)+translate(trimmed)+base.slice(start+trimmed.length);
      }
    }
    const elements=[...root.querySelectorAll('*')];
    if(root.nodeType===1)elements.unshift(root);
    for(const el of elements){
      const attrs=['title','aria-label','placeholder'];
      let cache=attributes.get(el);
      if(!cache){cache={};for(const a of attrs){if(el.hasAttribute(a))cache[a]=el.getAttribute(a);}attributes.set(el,cache);}
      for(const a of attrs){if(typeof cache[a]==='string' && ruToEn[cache[a]])el.setAttribute(a,translate(cache[a]));}
    }
    const btn=document.getElementById('language-toggle');
    if(btn){btn.textContent=lang==='ru'?'EN':'RU';btn.title=lang==='ru'?'Switch interface to English':'Переключить интерфейс на русский';}
    document.documentElement.lang=lang;
  }
  function setLanguage(next){
    lang=next==='en'?'en':'ru';
    try{localStorage.setItem('irina-language',lang);}catch(_){}
    apply();
  }
  function getLanguage(){return lang;}
  return {apply,setLanguage,getLanguage,translate};
})();
