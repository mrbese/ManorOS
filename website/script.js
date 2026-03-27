/**
 * script.js — ManorOS Landing Page
 * Handles scroll animations and interactive elements.
 */

document.addEventListener('DOMContentLoaded', () => {
  // Intersection Observer for scroll animations
  const observerOptions = {
    root: null,
    rootMargin: '0px',
    threshold: 0.15
  };

  const observer = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('in-view');
        // Stop observing after animation triggers
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  const animatedElements = document.querySelectorAll('.animate');
  animatedElements.forEach(el => observer.observe(el));

  // Add subtle mouse-tracking glow effect on feature cards
  const cards = document.querySelectorAll('.feature-card');
  cards.forEach(card => {
    card.addEventListener('mousemove', e => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      card.style.background = `radial-gradient(circle at ${x}px ${y}px, var(--surface-low) 0%, var(--surface) 100%)`;
    });
    
    card.addEventListener('mouseleave', () => {
      card.style.background = 'var(--surface)';
    });
  });
});
