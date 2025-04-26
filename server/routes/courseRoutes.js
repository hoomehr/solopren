const express = require('express');
const router = express.Router();
const courseController = require('../controllers/courseController');

// GET /api/courses - Get all courses with filtering and pagination
router.get('/', courseController.getCourses);

// GET /api/courses/:id - Get course by ID
router.get('/:id', courseController.getCourseById);

// POST /api/courses - Create a new course
router.post('/', courseController.createCourse);

// PUT /api/courses/:id - Update a course
router.put('/:id', courseController.updateCourse);

// DELETE /api/courses/:id - Delete a course
router.delete('/:id', courseController.deleteCourse);

module.exports = router;
