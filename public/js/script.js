// Configuration for Gemini AI
const API_KEY = 'YOUR_GEMINI_API_KEY'; // Replace with your actual API key when in production
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

  // Form submission (just prevent default for now since no backend)
  const form = document.querySelector('.signup-form');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      alert('Thanks for your interest! This would submit to a backend in production.');
      form.reset();
    });
  }

  // Course filtering
  setupCourseFiltering();

  // Initialize pagination
  setupPagination();
  
  // Initialize AI Chat
  setupAIChat();
});

// Course filtering functionality
function setupCourseFiltering() {
  const filterButtons = document.querySelectorAll('.filter-btn');
  const courseCards = document.querySelectorAll('.course-card');

  filterButtons.forEach(button => {
    button.addEventListener('click', () => {
      // Remove active class from all buttons
      filterButtons.forEach(btn => btn.classList.remove('active'));
      
      // Add active class to clicked button
      button.classList.add('active');
      
      // Get filter value
      const filterValue = button.getAttribute('data-filter');
      
      // Filter course cards
      courseCards.forEach(card => {
        if (filterValue === 'all' || card.getAttribute('data-category') === filterValue) {
          card.style.display = 'flex';
          // Add animation
          card.style.animation = 'fadeIn 0.5s';
        } else {
          card.style.display = 'none';
        }
      });
    });
  });
}

// Pagination functionality
function setupPagination() {
  const pageNumbers = document.querySelectorAll('.page-number');
  
  pageNumbers.forEach(page => {
    page.addEventListener('click', () => {
      // Remove active class from all page numbers
      pageNumbers.forEach(p => p.classList.remove('active'));
      
      // Add active class to clicked page number
      page.classList.add('active');
      
      // In a real application, this would load different course data
      // For now, we'll just show an alert
      console.log(`Page ${page.textContent} clicked`);
      
      // Scroll back to the top of the courses section
      document.querySelector('#courses').scrollIntoView({
        behavior: 'smooth',
        block: 'start'
      });
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
  function sendMessage() {
    const message = userInput.value.trim();
    if (message === '') return;

    // Add user message to chat
    addMessageToChat('user', message);
    userInput.value = '';

    // Process with Gemini AI or fallback
    if (chatSession) {
      processWithGemini(message);
    } else {
      // Fallback responses if Gemini is not available
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
