# Solopren - Empower Your Solo Journey

Solopren is a full-stack web application designed to help individuals become successful solo entrepreneurs by providing tools, materials, and guidance — whether it's a side project or their full-time focus.

## Features

- **Modern, Responsive Design**: Clean, light-themed interface with black cards and glowing effects
- **Standalone Courses Page**: Browse, filter, and paginate through available courses
- **Course & Story Detail Pages**: Dedicated pages for in-depth course information and success stories
- **Stylish Signup Section**: Black card with rounded corners and outer glow shadows for user registration
- **AI Assistant Integration**: Gemini AI-powered chat assistant to help solopreneurs
- **Full-Stack Architecture**: Express.js backend with API endpoints and MongoDB integration
- **Interactive UI**: Smooth animations, transitions, and user-friendly interface

## Tech Stack

### Frontend
- HTML5, CSS3
- Vanilla JavaScript
- Google Fonts (Inter, Poppins)
- Responsive design for all screen sizes

### Backend
- Node.js
- Express.js
- MongoDB (with Mongoose)
- RESTful API architecture

### AI Integration
- Google Gemini AI for the chat assistant

## Project Structure

```
solopren/
├── public/                  # Frontend assets
│   ├── css/                 # CSS stylesheets
│   ├── js/                  # JavaScript files
│   │   ├── script.js        # Main JavaScript file
│   │   ├── courses.js       # Courses page functionality
│   │   ├── course-detail.js # Course detail page functionality
│   │   └── story-detail.js  # Story detail page functionality
│   ├── images/              # Image assets
│   ├── index.html           # Homepage
│   ├── courses.html         # Courses page
│   ├── course-detail.html   # Course detail page
│   └── story-detail.html    # Story detail page
├── server/                  # Backend code
│   ├── models/              # MongoDB models
│   │   ├── Course.js        # Course model
│   │   └── User.js          # User model
│   ├── controllers/         # Route controllers
│   │   └── courseController.js # Course controller
│   ├── routes/              # API routes
│   │   └── courseRoutes.js  # Course routes
│   └── config/              # Configuration files
├── server.js                # Express server setup
├── package.json             # Project dependencies
└── .env                     # Environment variables
```

## Getting Started

1. Clone the repository
2. Install dependencies:
   ```
   npm install
   ```
3. Set up environment variables in `.env` file:
   ```
   PORT=3000
   MONGODB_URI=mongodb://localhost:27017/solopren
   NODE_ENV=development
   GEMINI_API_KEY=your_gemini_api_key_here
   ```
4. Start the development server:
   ```
   npm start
   ```
5. Open your browser and navigate to `http://localhost:3000`

## API Endpoints

- `GET /api/courses` - Get all courses with optional filtering and pagination
- `GET /api/courses/:id` - Get a specific course by ID
- `POST /api/chat` - Send a message to the AI assistant

## Pages

- `/` - Homepage with featured courses and success stories
- `/courses` - Browse and filter all available courses
- `/course-detail` - View detailed information about a specific course
- `/story-detail` - Read full success stories from solopreneurs

## Future Enhancements

- User authentication and profiles
- Course enrollment and progress tracking
- Payment integration for premium courses
- Community forum for solopreneurs
- Resource library with downloadable templates

## License

MIT License
