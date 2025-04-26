const mongoose = require('mongoose');

const CourseSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true
  },
  image: {
    type: String,
    required: true
  },
  category: {
    type: String,
    required: true,
    enum: ['business', 'tech', 'marketing', 'creative']
  },
  level: {
    type: String,
    required: true,
    enum: ['Beginner', 'Intermediate', 'Advanced']
  },
  price: {
    type: Number,
    required: true
  },
  instructor: {
    type: String,
    default: 'Solopren Team'
  },
  duration: {
    type: String,
    default: '4 weeks'
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Course', CourseSchema);
