// Configuration for Gemini AI
let genAI, model, chatSession;

document.addEventListener('DOMContentLoaded', () => {
  // Smooth scrolling for navigation links
  const scrollLinks = document.querySelectorAll('a[href^="#"]');
  
  scrollLinks.forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      
      const targetId = link.getAttribute('href');
      const targetElement = document.querySelector(targetId);
      
      if (targetElement) {
        targetElement.scrollIntoView({
          behavior: 'smooth',
          block: 'start'
        });
      }
    });
  });

  // Form submission with backend integration
  const form = document.querySelector('.signup-form');
  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      
      const nameInput = form.querySelector('input[type="text"]');
      const emailInput = form.querySelector('input[type="email"]');
      
      if (nameInput && emailInput) {
        try {
          // In a real app, this would be sent to the backend
          // const response = await fetch('/api/users/signup', {
          //   method: 'POST',
          //   headers: { 'Content-Type': 'application/json' },
          //   body: JSON.stringify({ name: nameInput.value, email: emailInput.value })
          // });
          
          // For now, just show success message
          alert('Thanks for your interest! You would be registered in a production environment.');
          form.reset();
        } catch (error) {
          console.error('Error submitting form:', error);
          alert('There was an error submitting the form. Please try again.');
        }
      }
    });
  }
  
  // Initialize AI Chat
  setupAIChat();
});

// Add active class to current nav link based on URL
function setActiveNavLink() {
  const currentPath = window.location.pathname;
  const navLinks = document.querySelectorAll('.nav-links a');
  
  navLinks.forEach(link => {
    const href = link.getAttribute('href');
    if (href === currentPath || 
        (currentPath === '/' && href === '/') ||
        (href !== '/' && currentPath.includes(href))) {
      link.classList.add('active');
    } else {
      link.classList.remove('active');
    }
  });
}

// Handle featured courses preview on homepage
function setupFeaturedCourses() {
  const featuredCoursesSection = document.getElementById('featured-courses');
  if (!featuredCoursesSection) return;
  
  // In a full implementation, this would fetch featured courses from the API
  // For now, we're using the static HTML
  
  // Add click event to the "View Course" buttons
  const viewButtons = document.querySelectorAll('.course-preview-card .btn-secondary');
  viewButtons.forEach(button => {
    button.addEventListener('click', (e) => {
      // This is handled by the href attribute, but we could add analytics here
      console.log('Course preview clicked');
    });
  });
}

// AI Chat functionality
function setupAIChat() {
  const chatToggle = document.getElementById('chatToggle');
  const chatWindow = document.getElementById('chatWindow');
  const chatMessages = document.getElementById('chatMessages');
  const userInput = document.getElementById('userInput');
  const sendBtn = document.getElementById('sendBtn');

  if (!chatToggle || !chatWindow || !chatMessages || !userInput || !sendBtn) {
    return; // Exit if elements don't exist
  }

  // Toggle chat window
  chatToggle.addEventListener('click', () => {
    chatWindow.classList.toggle('open');
  });

  // Initialize Gemini AI (if available)
  try {
    if (window.google && window.google.generativeai) {
      genAI = window.google.generativeai;
      initializeGeminiChat();
    } else {
      console.log('Gemini AI not loaded. Using mock responses.');
    }
  } catch (error) {
    console.error('Error initializing Gemini AI:', error);
  }

  // Send message on button click
  sendBtn.addEventListener('click', sendMessage);

  // Send message on Enter key press
  userInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      sendMessage();
    }
  });

  // Function to send message
  async function sendMessage() {
    const message = userInput.value.trim();
    if (message === '') return;

    // Add user message to chat
    addMessageToChat('user', message);
    userInput.value = '';

    try {
      // Try to use the backend API first
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ message })
      });
      
      if (response.ok) {
        const data = await response.json();
        addMessageToChat('bot', data.response);
        return;
      }
    } catch (error) {
      console.error('Error using backend chat API:', error);
    }
    
    // Fallback to client-side Gemini if available
    if (chatSession) {
      processWithGemini(message);
    } else {
      // Fallback responses if all else fails
      setTimeout(() => {
        const responses = [
          "I'm here to help you with your solopreneur journey!",
          "That's a great question about starting your business.",
          "Check out our courses for more detailed information on that topic.",
          "As a solopreneur, time management is crucial for success.",
          "Would you like me to recommend a specific resource for that?"
        ];
        const randomResponse = responses[Math.floor(Math.random() * responses.length)];
        addMessageToChat('bot', randomResponse);
      }, 1000);
    }
  }

  // Add message to chat UI
  function addMessageToChat(sender, text) {
    const messageDiv = document.createElement('div');
    messageDiv.classList.add('message');
    messageDiv.classList.add(sender === 'user' ? 'user-message' : 'bot-message');
    messageDiv.textContent = text;
    chatMessages.appendChild(messageDiv);
    
    // Scroll to the bottom of the chat
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }

  // Initialize Gemini Chat
  function initializeGeminiChat() {
    if (!API_KEY || API_KEY === 'YOUR_GEMINI_API_KEY') {
      console.log('No API key provided for Gemini. Using mock responses.');
      return;
    }

    try {
      genAI.configure({ apiKey: API_KEY });
      model = genAI.getGenerativeModel({ model: "gemini-pro" });
      chatSession = model.startChat({
        history: [
          {
            role: "user",
            parts: [{ text: "You are a helpful assistant for Solopren, a platform that helps individuals become successful solo entrepreneurs. Respond briefly and helpfully to questions about solopreneurship, business, and related topics."}],
          },
          {
            role: "model",
            parts: [{ text: "I'll be your Solopren assistant, providing concise and helpful information about solopreneurship and business topics. How can I help you today?"}],
          }
        ],
        generationConfig: {
          maxOutputTokens: 100,
        },
      });
    } catch (error) {
      console.error('Error setting up Gemini chat:', error);
    }
  }

  // Process message with Gemini AI
  async function processWithGemini(message) {
    try {
      const result = await chatSession.sendMessage(message);
      const response = await result.response;
      const text = response.text();
      addMessageToChat('bot', text);
    } catch (error) {
      console.error('Error getting response from Gemini:', error);
      addMessageToChat('bot', "I'm having trouble connecting to my brain right now. Please try again later.");
    }
  }
}

// Add fade-in animation
document.head.insertAdjacentHTML('beforeend', `
  <style>
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(20px); }
      to { opacity: 1; transform: translateY(0); }
    }
  </style>
`);

// Call initialization functions
setActiveNavLink();
setupFeaturedCourses();
