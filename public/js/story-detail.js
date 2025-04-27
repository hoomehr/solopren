document.addEventListener('DOMContentLoaded', function() {
    // Initialize the story detail page
    initStoryDetailPage();
});

// Initialize story detail page
function initStoryDetailPage() {
    // Add smooth scrolling for anchor links
    const anchorLinks = document.querySelectorAll('a[href^="#"]');
    anchorLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                window.scrollTo({
                    top: target.offsetTop - 80,
                    behavior: 'smooth'
                });
            }
        });
    });
    
    // Add event listeners to related story cards
    const storyCards = document.querySelectorAll('.story-card');
    storyCards.forEach(card => {
        card.addEventListener('click', () => {
            // In a full implementation, this would navigate to the specific story
            window.location.href = '/public/story-detail.html';
        });
    });
    
    // Add animation to blockquotes when they come into view
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.2
    });
    
    const quotes = document.querySelectorAll('.story-quote');
    quotes.forEach(quote => {
        observer.observe(quote);
    });
}
