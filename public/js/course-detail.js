document.addEventListener('DOMContentLoaded', function() {
    // Initialize the course detail page
    initCourseDetailPage();
});

// Initialize course detail page
function initCourseDetailPage() {
    // Add event listeners to course modules to make them expandable
    const moduleHeaders = document.querySelectorAll('.module-header');
    
    moduleHeaders.forEach(header => {
        header.addEventListener('click', () => {
            const moduleContent = header.nextElementSibling;
            const isOpen = moduleContent.style.maxHeight;
            
            // Close all other modules
            document.querySelectorAll('.module-content').forEach(content => {
                content.style.maxHeight = null;
                content.parentElement.classList.remove('open');
            });
            
            // Toggle current module
            if (!isOpen) {
                moduleContent.style.maxHeight = moduleContent.scrollHeight + 'px';
                moduleContent.parentElement.classList.add('open');
            }
        });
    });
    
    // Add event listener to enroll button
    const enrollButton = document.querySelector('.btn-primary.btn-large');
    if (enrollButton) {
        enrollButton.addEventListener('click', () => {
            alert('Thank you for your interest! Enrollment functionality will be available soon.');
        });
    }
    
    // Add event listeners to related course cards
    const courseCards = document.querySelectorAll('.course-card');
    courseCards.forEach(card => {
        card.addEventListener('click', () => {
            // In a full implementation, this would navigate to the specific course
            window.location.href = '/public/course-detail.html';
        });
    });
}
