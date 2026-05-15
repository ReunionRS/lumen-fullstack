let nav = document.querySelector("nav");
let scrollBtn = document.querySelector(".scroll-button a");

window.onscroll = function () {
  if (document.documentElement.scrollTop > 20) {
    nav.classList.add("sticky");
    scrollBtn.style.display = "block";
  } else {
    nav.classList.remove("sticky");
    scrollBtn.style.display = "none";
  }
};

let body = document.querySelector("body");
let navBar = document.querySelector(".navbar");
let menuBtn = document.querySelector(".menu-btn");
let cancelBtn = document.querySelector(".cancel-btn");

menuBtn.onclick = function () {
  navBar.classList.add("active");
  menuBtn.style.opacity = "0";
  menuBtn.style.pointerEvents = "none";
  body.style.overflow = "hidden";
  scrollBtn.style.pointerEvents = "none";
};

const hideNavMenu = () => {
  navBar.classList.remove("active");
  menuBtn.style.opacity = "1";
  menuBtn.style.pointerEvents = "auto";
  body.style.overflow = "auto";
  scrollBtn.style.pointerEvents = "auto";
};

cancelBtn.onclick = hideNavMenu;

let navLinks = document.querySelectorAll(".menu li a");
navLinks.forEach((link) => {
  link.addEventListener("click", hideNavMenu);
});

document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    e.preventDefault();
    const target = document.querySelector(this.getAttribute('href'));
    
    if (target) {
      const offsetTop = target.offsetTop - 70;
      
      window.scrollTo({
        top: offsetTop,
        behavior: 'smooth'
      });
    }
  });
});


const companiesData = {
  '28q': {
    title: '28Q',
    logo: 'images/logo-company/28q.png',
    description: 'Видеостудия полного цикла, специализирующаяся на создании контента от идеи до публикации. Команда профессионалов с опытом в разных сферах медиапроизводства.',
    services: [
      'Контент-продакшн полного цикла',
      'Видеопроизводство и монтаж',
      'Разработка уникальных решений',
      'Мониторинг и анализ эффективности'
    ],
    project: 'Разработал корпоративный сайт видеостудии с портфолио работ, системой заказа услуг и интеграцией с социальными сетями.',
    website: 'https://www.28q.ru'
  },
  'vprussia': {
    title: 'VP Russia',
    logo: 'images/logo-company/VPrussia.png',
    description: 'Ведущий ресурс о виртуальном производстве в России. Освещает новости, технологии и тенденции в сфере Virtual Production для кино и телевидения.',
    services: [
      'Новости виртуального производства',
      'Образовательные материалы и курсы',
      'Каталог участников рынка VP',
      'Консультации по внедрению технологий'
    ],
    project: 'Создал информационный портал с системой публикации статей, каталогом компаний и интерактивной картой участников индустрии.',
    website: 'https://vprussia.ru'
  },
  'reunion': {
    title: 'Reunion Production',
    logo: 'images/logo-company/Reunion.jpg',
    description: 'Студия VFX и CGI графики, специализирующаяся на создании визуальных эффектов для кино, рекламы и игр. Высокое качество и инновационные решения.',
    services: [
      'Визуальные эффекты для кино',
      'CGI анимация и моделирование',
      'Post-production услуги',
      'Разработка игровых ассетов'
    ],
    project: 'Разработал корпоративный сайт-портфолио с галереей проектов, системой демо-рил и формой для заказа услуг.',
    website: 'https://reunionproduction.ru'
  },
  'reputation': {
    title: 'Репутация',
    logo: 'images/logo-company/Reputatcia.png',
    description: 'Строительная компания в Ижевске, специализирующаяся на жилом и коммерческом строительстве. Качественные материалы и надежное исполнение проектов.',
    services: [
      'Жилое строительство',
      'Коммерческая недвижимость',
      'Ремонт и реконструкция',
      'Проектирование и дизайн'
    ],
    project: 'Создал корпоративный сайт с каталогом объектов, калькулятором стоимости и системой онлайн-консультаций.',
    website: 'https://mdreputation.ru'
  },
  'notagency': {
    title: 'НеРекламное Агентство',
    logo: 'images/logo-company/NeAgentstvo.jpg',
    description: 'Digital-агентство полного цикла, специализирующееся на комплексном маркетинге. Команда профессионалов, превращающих идеи в результаты.',
    services: [
      'Digital-маркетинг и стратегии',
      'Веб-разработка и дизайн',
      'SMM и контент-маркетинг',
      'Брендинг и айдентика'
    ],
    project: 'Разработал корпоративный сайт агентства с портфолио проектов, блогом и системой подачи заявок на услуги.',
    website: 'https://notagancy.ru'
  }
};

document.addEventListener('DOMContentLoaded', function() {
  const modal = document.getElementById('modal-overlay');
  const modalClose = document.querySelector('.modal-close');
  const clientLogos = document.querySelectorAll('.clients-track img[data-company]');

  clientLogos.forEach(logo => {
    logo.addEventListener('click', function() {
      const companyKey = this.getAttribute('data-company');
      const company = companiesData[companyKey];
      
      if (company) {
        document.querySelector('.modal-logo').src = company.logo;
        document.querySelector('.modal-logo').alt = company.title;
        document.querySelector('.modal-title').textContent = company.title;
        document.querySelector('.modal-description').textContent = company.description;
        document.querySelector('.project-description').textContent = company.project;
        document.querySelector('.modal-link').href = company.website;
        
        const servicesList = document.querySelector('.services-list');
        servicesList.innerHTML = '';
        company.services.forEach(service => {
          const li = document.createElement('li');
          li.textContent = service;
          servicesList.appendChild(li);
        });
        
        modal.classList.add('active');
        body.style.overflow = 'hidden';
      }
    });
  });

  function closeModal() {
    modal.classList.remove('active');
    body.style.overflow = 'auto';
  }

  modalClose.addEventListener('click', closeModal);
  
  modal.addEventListener('click', function(e) {
    if (e.target === modal) {
      closeModal();
    }
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && modal.classList.contains('active')) {
      closeModal();
    }
  });
});