// courses.js - Handles course page specific functionality

document.addEventListener('DOMContentLoaded', () => {
    // References to DOM elements
    const coursesGallery = document.getElementById('coursesGallery');
    const pagination = document.getElementById('coursesPagination');
    const filterButtons = document.querySelectorAll('.filter-btn');
    
    // State
    let currentPage = 1;
    let currentFilter = 'all';
    let courses = [];
    let totalPages = 0;
    
    // Initialize courses page
    initCoursesPage();
    
    // Add event listeners to filter buttons
    filterButtons.forEach(button => {
        button.addEventListener('click', () => {
            // Update active button
            filterButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');
            
            // Get filter value
            currentFilter = button.getAttribute('data-filter');
            currentPage = 1;
            
            // Fetch courses with filter
            fetchCourses(currentPage, currentFilter);
        });
    });
    
    // Initialize courses page
    function initCoursesPage() {
        // First show the static content, then try to fetch from API
        setupInitialCourses();
        fetchCourses(currentPage, currentFilter);
    }
    
    // Setup initial courses with static content
    function setupInitialCourses() {
        const courseCards = document.querySelectorAll('.course-card');
        
        // Add animation to initial cards
        courseCards.forEach(card => {
            card.style.animation = 'fadeIn 0.5s';
        });
        
        // Add click events to course cards
        courseCards.forEach(card => {
            card.addEventListener('click', () => {
                // Navigate to the course detail page
                window.location.href = '/course-detail';
            });
        });
        
        // Set up initial pagination
        renderPagination(1, 1);
    }
    
    // Fetch courses from API
    async function fetchCourses(page, filter) {
        try {
            // Show loading state
            const loadingSpinner = document.createElement('div');
            loadingSpinner.className = 'loading-spinner';
            loadingSpinner.textContent = 'Loading courses...';
            
            // Only show loading spinner if we're replacing the content
            if (filter !== 'all' || page !== 1) {
                coursesGallery.innerHTML = '';
                coursesGallery.appendChild(loadingSpinner);
            }
            
            const url = `/api/courses?page=${page}&filter=${filter}`;
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error('Failed to fetch courses');
            }
            
            const data = await response.json();
            courses = data.courses;
            totalPages = data.totalPages;
            
            renderCourses(courses);
            renderPagination(totalPages, currentPage);
        } catch (error) {
            console.error('Error fetching courses:', error);
            
            // For development, use mock data if API fails
            if (filter !== 'all') {
                // Filter the static content if needed
                filterStaticCourses(filter);
            }
        }
    }
    
    // Filter static courses when API fails
    function filterStaticCourses(filter) {
        const courseCards = document.querySelectorAll('.course-card');
        
        courseCards.forEach(card => {
            if (filter === 'all' || card.getAttribute('data-category') === filter) {
                card.style.display = 'flex';
                card.style.animation = 'fadeIn 0.5s';
            } else {
                card.style.display = 'none';
            }
        });
    }
    
    // Render courses to the DOM
    function renderCourses(courses) {
        // Only clear existing courses if we have new data from the API
        if (courses && courses.length > 0) {
            // Clear existing courses
            coursesGallery.innerHTML = '';
            
            // Render each course
            courses.forEach(course => {
                const courseCard = document.createElement('div');
                courseCard.className = 'course-card';
                courseCard.setAttribute('data-category', course.category);
                
                courseCard.innerHTML = `
                    <div class="course-img">
                        <img src="${course.image}" alt="${course.title}">
                    </div>
                    <div class="course-content">
                        <h3>${course.title}</h3>
                        <p>${course.description}</p>
                        <div class="course-details">
                            <span class="course-level">${course.level}</span>
                            <span class="course-price">$${course.price}</span>
                        </div>
                    </div>
                `;
                
                coursesGallery.appendChild(courseCard);
                
                // Add animation
                courseCard.style.animation = 'fadeIn 0.5s';
                
                // Add click event
                courseCard.addEventListener('click', () => {
                    // Navigate to the course detail page
                    window.location.href = '/course-detail';
                });
            });
        } else if (courses && courses.length === 0) {
            // No courses found
            coursesGallery.innerHTML = '<p class="no-courses">No courses found matching your criteria.</p>';
        }
        // If courses is null or undefined, we keep the static content
    }
    
    // Render pagination controls
    function renderPagination(totalPages, currentPage) {
        pagination.innerHTML = '';
        
        for (let i = 1; i <= totalPages; i++) {
            const pageNumber = document.createElement('div');
            pageNumber.className = 'page-number' + (i === currentPage ? ' active' : '');
            pageNumber.textContent = i;
            
            pageNumber.addEventListener('click', () => {
                if (i !== currentPage) {
                    currentPage = i;
                    fetchCourses(currentPage, currentFilter);
                    
                    // Scroll back to the top of the courses section
                    document.querySelector('#courses').scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            });
            
            pagination.appendChild(pageNumber);
        }
    }
    
    // Use mock data for development if API fails
    function useMockData() {
        const mockCourses = [
            {
                id: 1,
                title: "Solopreneur Business Foundations",
                description: "Learn how to create a solid foundation for your solo business venture.",
                image: "https://source.unsplash.com/random/600x400/?business",
                category: "business",
                level: "Beginner",
                price: 49
            },
            {
                id: 2,
                title: "Building Your Online Presence",
                description: "Create a professional online presence with minimal technical knowledge.",
                image: "https://source.unsplash.com/random/600x400/?coding",
                category: "tech",
                level: "Intermediate",
                price: 79
            },
            {
                id: 3,
                title: "Digital Marketing Essentials",
                description: "Master the fundamentals of digital marketing to grow your solo business.",
                image: "https://source.unsplash.com/random/600x400/?marketing",
                category: "marketing",
                level: "Beginner",
                price: 59
            },
            {
                id: 4,
                title: "Creative Content Production",
                description: "Learn to create engaging content that showcases your unique perspective.",
                image: "https://source.unsplash.com/random/600x400/?design",
                category: "creative",
                level: "Advanced",
                price: 89
            },
            {
                id: 5,
                title: "Financial Management for Solopreneurs",
                description: "Take control of your finances and maximize profitability.",
                image: "https://source.unsplash.com/random/600x400/?finance",
                category: "business",
                level: "Intermediate",
                price: 69
            },
            {
                id: 6,
                title: "Automation for Solo Businesses",
                description: "Use technology to automate tasks and scale your business efficiently.",
                image: "https://source.unsplash.com/random/600x400/?automation",
                category: "tech",
                level: "Advanced",
                price: 99
            }
        ];
        
        // Filter courses if needed
        const filteredCourses = currentFilter === 'all' 
            ? mockCourses 
            : mockCourses.filter(course => course.category === currentFilter);
        
        renderCourses(filteredCourses);
        renderPagination(1, 1); // Mock single page for now
    }
});
