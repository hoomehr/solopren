const Course = require('../models/Course');

// Get all courses with filtering and pagination
exports.getCourses = async (req, res) => {
  try {
    const { page = 1, filter = 'all', limit = 6 } = req.query;
    const pageSize = parseInt(limit);
    const skip = (parseInt(page) - 1) * pageSize;
    
    // Build query based on filter
    const query = filter !== 'all' ? { category: filter } : {};
    
    // Get total count for pagination
    const totalCourses = await Course.countDocuments(query);
    const totalPages = Math.ceil(totalCourses / pageSize);
    
    // Get courses with pagination
    const courses = await Course.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(pageSize);
    
    res.json({
      courses,
      totalPages,
      currentPage: parseInt(page),
      totalCourses
    });
  } catch (error) {
    console.error('Error fetching courses:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get course by ID
exports.getCourseById = async (req, res) => {
  try {
    const course = await Course.findById(req.params.id);
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    res.json(course);
  } catch (error) {
    console.error('Error fetching course:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Create a new course
exports.createCourse = async (req, res) => {
  try {
    const { title, description, image, category, level, price } = req.body;
    
    // Validate required fields
    if (!title || !description || !image || !category || !level || !price) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Create new course
    const newCourse = new Course({
      title,
      description,
      image,
      category,
      level,
      price,
      instructor: req.body.instructor || 'Solopren Team',
      duration: req.body.duration || '4 weeks'
    });
    
    const savedCourse = await newCourse.save();
    res.status(201).json(savedCourse);
  } catch (error) {
    console.error('Error creating course:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Update a course
exports.updateCourse = async (req, res) => {
  try {
    const course = await Course.findByIdAndUpdate(
      req.params.id,
      { $set: req.body },
      { new: true, runValidators: true }
    );
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    res.json(course);
  } catch (error) {
    console.error('Error updating course:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// Delete a course
exports.deleteCourse = async (req, res) => {
  try {
    const course = await Course.findByIdAndDelete(req.params.id);
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    res.json({ message: 'Course deleted successfully' });
  } catch (error) {
    console.error('Error deleting course:', error);
    res.status(500).json({ message: 'Server error' });
  }
};
