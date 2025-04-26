const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');
require('dotenv').config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Serve static files from the public directory
app.use(express.static(path.join(__dirname, 'public')));

// MongoDB Connection (commented out until MongoDB is set up)
/*
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/solopren', {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log('MongoDB connected'))
.catch(err => console.error('MongoDB connection error:', err));
*/

// Course Model (temporary in-memory for development)
const courses = [
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

// API Routes

// Get all courses with optional filtering
app.get('/api/courses', (req, res) => {
  const { page = 1, filter = 'all' } = req.query;
  const pageSize = 6;
  
  // Filter courses if needed
  const filteredCourses = filter === 'all' 
    ? courses 
    : courses.filter(course => course.category === filter);
  
  // Calculate pagination
  const totalPages = Math.ceil(filteredCourses.length / pageSize);
  const startIndex = (page - 1) * pageSize;
  const paginatedCourses = filteredCourses.slice(startIndex, startIndex + pageSize);
  
  res.json({
    courses: paginatedCourses,
    totalPages,
    currentPage: parseInt(page),
    totalCourses: filteredCourses.length
  });
});

// Get course by ID
app.get('/api/courses/:id', (req, res) => {
  const course = courses.find(c => c.id === parseInt(req.params.id));
  
  if (!course) {
    return res.status(404).json({ message: 'Course not found' });
  }
  
  res.json(course);
});

// Gemini AI Integration endpoint (placeholder)
app.post('/api/chat', (req, res) => {
  const { message } = req.body;
  
  // This would be where you'd integrate with Gemini API
  // For now, return a mock response
  res.json({
    response: `This is a mock response to: "${message}". In production, this would connect to Gemini AI.`
  });
});

// Serve the main index.html for the root route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Serve the courses.html for the /courses route
app.get('/courses', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'courses.html'));
});

// Handle 404 - serve index.html for client-side routing
app.use((req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Visit http://localhost:${PORT} to view the application`);
});
