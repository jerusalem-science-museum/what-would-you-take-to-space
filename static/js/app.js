function applyLanguage(lang) {
    document.querySelectorAll(".lang").forEach(el => {
      const key = el.dataset.key;
      el.textContent = translations[lang][key] || "";
    });
  }
  
  // on page load:
  applyLanguage("en");
  
  // on language change:
  languageToggle.addEventListener("change", e => {
    applyLanguage(e.target.value); // "en" or "he"
  });