# Basic test requires
require 'minitest/autorun'
require 'minitest/pride'
require 'pry'

# Include both the migration and the app itself
require './migration'
require './application'

# Overwrite the development database connection with a test connection.
ActiveRecord::Base.establish_connection(
  adapter:  'sqlite3',
  database: 'test.sqlite3'
)

# Gotta run migrations before we can run tests.  Down will fail the first time,
# so we wrap it in a begin/rescue.
begin ApplicationMigration.migrate(:down); rescue; end
ApplicationMigration.migrate(:up)

# Finally!  Let's test the thing.
class ApplicationTest < Minitest::Test

  #Person A Tests
  def setup
    @school = School.create(name: "Starfleet Academy")
    @term = Term.create(name: "Fall Term", starts_on: "2004-05-26", ends_on: Date.today, school_id: 1, school: @school)
    @term_two = Term.create(name: "Spring Term", starts_on: "1988-05-10", ends_on: Date.today, school_id: 1, school: @school)
    @course = Course.create(name: "Advanced Subspace Geometry", term: @term, course_code: "ncc1701")
    @course_two = Course.create(name: "Basic Warp Design", term: @term, course_code: "ncc74210")
    @course_student = CourseStudent.create(course: @course)
    @course_student_two = CourseStudent.create(course: @course)
    @assignment = Assignment.create(name: "Cochrane Theory for Dummies", course: @course, active_at: "1933-01-23", due_at: "1989-11-20", percent_of_grade: 0.25)
    @assignment_two = Assignment.create(name: "Transwarp Initiatives for cleaner space lanes", course: @course, active_at: "1947-07-20", due_at: "1982-08-15", percent_of_grade: 0.52)
    @assignment_three = Assignment.create(name: "Test Assignment Three", course: @course, active_at: "1954-05-10", due_at: "1989-11-20", percent_of_grade: 0.34)
    @lesson = Lesson.create(name: "First Lesson", pre_class_assignment: @assignment)
    @lesson_two = Lesson.create(name: "Second Lesson", pre_class_assignment: @assignment, parent_lesson: @lesson)
    @lesson_three = Lesson.create(name: "Third Lesson", parent_lesson: @lesson)
    @assignment_grade = AssignmentGrade.create(assignment: @assignment)
    @assignment_grade_two = AssignmentGrade.create(assignment: @assignment)
  end

  def test_truth
    assert true
  end

  def test_school_has_many_terms
    assert @school.persisted?
    assert @school.terms.first == @term
    assert_equal 2, @school.terms.length
  end

  def test_term_belongs_to_school
    assert @term.persisted?
    assert @term.school == @school
  end

  def test_term_has_many_courses
    assert_equal @course, @term.courses.first
    assert_equal 2, @term.courses.length
  end

  def test_course_belongs_to_term
    assert @course.persisted?
    assert_equal @term, @course.term
  end

  def test_cant_delete_term_with_courses
    refute @term.destroy
    assert @term.errors.full_messages.include?("Cannot delete record because dependent courses exist")
    assert Term.exists?(name: "Fall Term")
  end

  def test_courses_have_many_course_students
    assert_equal @course_student, @course.course_students.first
    assert_equal @course_student_two, @course.course_students.last
    assert_equal 2, @course.course_students.length
  end

  def test_course_student_belongs_to_course
    assert @course_student.persisted?
    assert_equal @course, @course_student.course
  end

  def test_cant_delete_course_with_students
    refute @course.destroy
    assert @course.errors.full_messages.include?("Cannot delete record because dependent course students exist")
    assert Course.exists?(name: "Advanced Subspace Geometry")
  end

  def test_courses_have_many_assignments
    assert_equal 3, @course.assignments.length
  end

  def test_assignment_belongs_to_course
    assert @assignment.persisted?
    assert_equal @course, @assignment.course
  end

  def test_assignments_are_deleted_with_course
    assignment = Assignment.create(name: "Intermix Chamber", course: @course_two)
    @course_two.destroy
    refute assignment.persisted?
    refute Assignment.exists?(name: "Intermix Chamber")
  end

  def test_lesson_belongs_to_assignment
    assert @lesson.persisted?
    assert @assignment, @lesson.pre_class_assignment
  end

  def test_assignment_has_many_lessons
    assert_equal @lesson, @assignment.pre_class_lessons.first
    assert_equal @lesson_two, @assignment.pre_class_lessons.last
    assert_equal 2, @assignment.pre_class_lessons.length
  end

  def test_school_has_many_courses_through_terms
    assert_equal @course, @school.courses.first
    assert_equal @course_two, @school.courses.last
    assert_equal 2, @school.courses.length
  end

  def test_lesson_has_a_name
    lesson = Lesson.new
    refute lesson.save
    assert lesson.errors.full_messages.include?("Name can't be blank")
  end

  def test_readings_has_an_order_number
    reading = Reading.new
    refute reading.save
    assert reading.errors.full_messages.include?("Order number can't be blank")
  end

  def test_reading_has_a_lesson_id
    reading = Reading.new
    refute reading.save
    assert reading.errors.full_messages.include?("Lesson can't be blank")
  end

  def test_reading_has_a_url
    reading = Reading.new
    refute reading.save
    assert reading.errors.full_messages.include?("Url can't be blank")
  end

  def test_reading_has_url_in_specific_format
    reading = Reading.new(url: "www.resistanceisfutile.com")
    refute reading.save
    assert reading.errors.full_messages.include?("Url is invalid")
    reading_two = Reading.new(order_number: 1, lesson_id: 1, url: "http://borg.com")
    assert reading_two.save
    reading_three = Reading.new(order_number: 1, lesson_id: 1, url: "https://borg.com")
    assert reading_three.save
  end

  def test_course_has_a_name
    course = Course.new
    refute course.save
    assert course.errors.full_messages.include?("Name can't be blank")
  end

  def test_course_code_is_unique_per_term
    course = Course.new(name: "Communications", course_code: "ncc1371", term: @term)
    assert course.save
    course_two = Course.new(name: "Exochemistry", course_code: "ncc1371", term: @term)
    refute course_two.save
    assert course_two.errors.full_messages.include?("Course code has already been taken")
  end

  def test_course_code_is_in_specific_format
    course = Course.new(name: "Interspecies Protocol", course_code: "borg", term: @term)
    refute course.save
    course.errors.full_messages.include?("Course code is invalid")
  end

  def test_course_instructor_belongs_to_instructor
    user = User.create(first_name: "Test", last_name: "Test", email: "borg2@borg.com", photo_url: "http://borg1.com")
    course_instructor = CourseInstructor.create(instructor: user)
    assert user.persisted?
    assert_equal user, course_instructor.instructor
  end

  def test_assignment_has_many_assignment_grades
    assert_equal @assignment_grade, @assignment.assignment_grades.first
    assert_equal @assignment_grade_two, @assignment.assignment_grades.last
    assert_equal 2, @assignment.assignment_grades.length
  end

  def test_assignment_grade_belongs_to_assignment
    assert @assignment_grade.persisted?
    assert @assignment.persisted?
    assert_equal @assignment, @assignment_grade.assignment
  end

  def test_course_has_many_instructors_through_course_instructors
    user = User.create(first_name: "Test", last_name: "Test", email: "borg3@borg.com", photo_url: "http://borg2.com")
    @course.instructors << user
    assert_equal 1, @course.instructors.length
  end

  def test_assignment_due_date_is_after_assignment_active_date
    assignment = Assignment.create(active_at: Date.today, due_at: "1988-05-10")
    refute assignment.save
    assert assignment.errors.full_messages.include?("Due at date cannot be before active at date.")
  end

  def test_assignments_are_ordered_by_due_at_then_active_at
    assert_equal [@assignment_two, @assignment, @assignment_three], @course.assignments.to_a
  end

  def test_lesson_has_many_child_lessons
    assert_equal [@lesson_two, @lesson_three], @lesson.child_lessons.to_a
  end

  def test_child_lessons_belong_to_parent_lesson
    assert_equal @lesson, @lesson_two.parent_lesson
    assert_equal @lesson, @lesson_three.parent_lesson
  end

# The following is Person A's version of test
# Person B also wrote a test for the same problem
  def test_child_lessons_are_ordered_by_id
    lesson = Lesson.create(name: "Parent Lesson")
    lesson1 = Lesson.create(name: "First Child Lesson")
    lesson2 = Lesson.create(name: "Second Child Lesson")
    lesson3 = Lesson.create(name: "Third Child Lesson")
    lesson4 = Lesson.create(name: "Fourth Child Lesson")
    lesson.child_lessons << lesson2
    lesson.child_lessons << lesson4
    lesson.child_lessons << lesson1
    lesson.child_lessons << lesson3
    assert lesson.child_lessons.first == lesson1
    assert_equal [lesson1, lesson2, lesson3, lesson4], lesson.child_lessons.to_a
    assert_equal 4, lesson.child_lessons.length
  end

# End Person A Tests

  # B-Test-1
  def test_a_reading_is_destroyed_when_its_lesson_is_destroyed
    lesson_test = Lesson.create(course_id: 99, parent_lesson_id: 99, name: "Test Reading destroyed", pre_class_assignment_id: 1, in_class_assignment_id: 1)

    Reading.create(lesson_id: lesson_test.id, caption: "Testy test", order_number: 66)

    lesson_test.destroy
    refute Reading.find_by(caption: "Testy test")
  end

  #B-Test-2
  def test_destroying_a_course_destroys_its_associated_lessons
    course_test = Course.create(name: "Destroying lessons like a BAWSS", course_code: "ncc74656")

    Lesson.create(course_id: course_test.id, parent_lesson_id: 99, name: "Destroy this lesson!")

    Lesson.create(course_id: course_test.id, parent_lesson_id: 99, name: "Destroy this lesson too!")

    course_test.destroy
    refute Lesson.find_by(name: "Destroy this lesson!")
    refute Lesson.find_by(name: "Destroy this lesson too!")
  end

  #B-Test-3
  def test_that_a_course_with_instructors_cannot_be_deleted
    course_test = Course.create(name: "Destroying lessons like a BAWSS", course_code: "ncc1764")
    CourseInstructor.create(course_id: course_test.id)

    refute course_test.destroy
  end

  #B-Test-4
  def test_that_a_lesson_is_associated_with_its_in_class_assignment
    assign_test = Assignment.create(name: "Assignment Test", course_id: @course.id, percent_of_grade: 0.34, active_at: Date.today, due_at: "2017-05-15")
    assert assign_test.persisted?
    assert assign_test.save!

    lesson_test = Lesson.create(name: "Test In Class Lesson is associated",in_class_assignment: assign_test)
    assert lesson_test.persisted?
    assert lesson_test.save!
    assert lesson_test.in_class_assignment == assign_test
  end

  #B-Test-5
  def test_a_course_has_many_readings_through_lessons
    course_many_readings_test = Course.create(name: "Advanced Lesson Destroying", course_code: "ncc2000")

    lesson_test = Lesson.create(course_id: course_many_readings_test.id, name: "Lesson Destroying Best Practices")

    lesson_test2 = Lesson.create(course_id: course_many_readings_test.id, name: "Lesson Destroying: Safety")

    Reading.create(lesson_id: lesson_test.id, caption: "Lesson Destroying: Industry Methods and Standards", url: "http://destroythelesson.com", order_number: 1)

    Reading.create(lesson_id: lesson_test.id, caption: "How to destroy Lessons Safely", url: "http://destroythelesson.com", order_number: 1)

    Reading.create(lesson_id: lesson_test2.id, caption: "What to do after you've destroyed a lesson",url: "http://destroythelesson.com", order_number: 1)

    assert course_many_readings_test.readings.count > 2
  end

  #B-Test-6
  def test_validate_a_school_has_a_name
    new_school = School.create()
    assert new_school.name == nil
    assert new_school.errors.messages
    refute new_school.save
  end

  #The following tests come from a single deliverable.
  #B-Test-7
  #Date (used later) requires YYYY-MM-DD format
  def test_validate_terms_must_have_a_name
    terms_have_names = Term.new()
    assert terms_have_names.name == nil
    assert terms_have_names.errors.messages
    refute terms_have_names.save
  end

  def test_validate_terms_must_have_starts_on
    terms_have_starts_on = Term.new(name: "Winter")
    assert terms_have_starts_on.starts_on == nil
    assert terms_have_starts_on.errors.messages
    refute terms_have_starts_on.save
  end

  def test_validate_terms_must_have_ends_on
    terms_have_ends_on = Term.new(name: "Spring", starts_on: "2017-02-16")
    assert terms_have_ends_on.ends_on == nil
    assert terms_have_ends_on.errors.messages
    refute terms_have_ends_on.save
  end

  def test_validate_terms_must_have_a_school_id
    terms_have_school_id = Term.new(name: "Summer", starts_on: Date.today, ends_on: "2017-04-29")
    assert terms_have_school_id.school_id == nil
    assert terms_have_school_id.errors.messages
    refute terms_have_school_id.save
  end

  #B-Test-8
  #The following tests come from a single deliverable
  def test_that_a_user_has_a_first_name
    user_first_name = User.create()
    assert user_first_name.first_name == nil
    assert user_first_name.errors.messages
    refute user_first_name.save
  end

  def test_that_a_user_has_a_last_name
    user_last_name = User.create(first_name: "Bobby")
    assert user_last_name.last_name == nil
    assert user_last_name.errors.messages
    refute user_last_name.save
  end

  def test_that_a_user_has_an_email
    user_email = User.create(first_name: "Bobby", last_name: "Tables")
    assert user_email.email == ""
    assert user_email.errors.messages
    refute user_email.save
  end

  #B-Test-9
  def test_that_a_users_email_is_unique
    unique_email = User.create(first_name: "Bobby", last_name: "Tables", email: "dropallthetables@dropitlikeitshot.com", photo_url: "https://xkcd.com/327/")
    assert unique_email.save!

    unique_email1 = User.create(first_name: "Fred", last_name: "Dunston", email: "dropallthetables@dropitlikeitshot.com", photo_url: "https://xkcd.com/327/")
    refute unique_email1.save
    assert unique_email1.errors.full_messages
  end

  # #B-Test-10
  def test_that_a_user_email_matches_a_pattern
    email_pattern = User.new(first_name:"Jean Luc", middle_name: "Luc", last_name: "Picard", email: "capt_jean_luc_picardoftheussenterprise")
    refute email_pattern.save

    email_pattern2 = User.new(first_name: "Jean", middle_name: "Luc", last_name: "Picard", email: "CaptJeanLucPicard@Enterprise.com", photo_url:"https://terrygotham.files.wordpress.com/2014/01/dh4og59.jpg")
    assert email_pattern2.save!
  end

  #The following tests come from a single deliverable
  #B-Test-11
  def test_that_a_users_photo_url_begins_with_http
    pic_pattern_standard = User.new(first_name: "Nerys", last_name: "Kira", email: "keepresisting@resistance.com", photo_url: "vivaleresistance.png")

    refute pic_pattern_standard.save
    assert pic_pattern_standard.errors.messages

    pic_pattern_http = User.new(first_name: "Jake", last_name:  "Sisko", email: "journalist@ds9.com", photo_url: "http://www.ds9.com/employees/pictures/saycheese.png")
    assert pic_pattern_http.errors.full_messages
    assert pic_pattern_http.save!
  end

  def test_that_a_users_photo_url_begins_with_https
    pic_pattern_secure = User.new(first_name: "Benjamin", last_name: "Sisko", email: "baseballislife@ds9.com", photo_url: "wickedfastball.jpg")
    refute pic_pattern_secure.save
    assert pic_pattern_secure.errors.full_messages

    pic_pattern_https = User.new(first_name: "Benjamin", last_name: "Sisko", email: "baseballislife@ds9.com", photo_url: "https://www.ds9.com/employees/pictures/wickedfastball.jpg")
    assert pic_pattern_https.errors.full_messages
    assert pic_pattern_https.save!
  end

  #The following tests come from one delivaerable
  #B-Test-12
  def test_that_assignments_have_a_name
    assignment_noname = Assignment.new(name:"")
    assert assignment_noname.name == ""
    refute assignment_noname.save

    assignment_name = Assignment.new(name: "Star Trekkin' across the Universe", course_id: @course.id, percent_of_grade: 0.95)
    assert assignment_name.name == "Star Trekkin' across the Universe"
    assert assignment_name.save
  end

  def test_that_assignments_have_a_course_id
    assignment_not_have_course_id = Assignment.new(name: "Only going forward because we can't find reverse!")
    refute assignment_not_have_course_id.save

    assignment_has_course_id = Assignment.new(name: "There's Klingons on the starboard bow, scrape them off Jim!", course_id: @course.id, percent_of_grade: 0.33)
    assert assignment_has_course_id.save!
  end

  def test_that_assignments_have_a_percent_of_grade
    assignment_no_pog = Assignment.new(name: "It's life Jim, but not as we know it.", course_id: @course.id)
    refute assignment_no_pog.save

    assignment_has_pog = @assignment
    assert assignment_has_pog.save
  end

  #B-Test-13
  def test_that_the_assignment_name_is_unique_within_a_given_course_id
    assignment_unique = Assignment.new(name: "Avoiding Transporter Buffer Overruns", course_id: @course.id, percent_of_grade: 0.30 )
    assert assignment_unique.save

    assignment_not_unique = Assignment.new(name: "Avoiding Transporter Buffer Overruns", course_id: @course.id, percent_of_grade: 0.45)
    refute assignment_not_unique.save
    assert assignment_not_unique.errors.full_messages.include?("Name has already been taken")
  end

  #B Adventurer Mode
  #B-Test-14
  def test_that_course_students_are_associated_with_students
    new_user = User.create(first_name: "Alexander", last_name: "Rozhenko", email: "mydadisawarrior@ds9.com", photo_url: "https://vignette2.wikia.nocookie.net/startrek/images/8/8c/Alexander2374.jpg/revision/latest?cb=20060627132913")
    assert new_user.save!

    course_student = CourseStudent.create(student: new_user, student_id: new_user.id, course_id: @course.id)
    assert course_student.student_id == new_user.id
  end

  #B-Test-15
  def test_that_course_students_are_associated_with_assignment_grades
    student_grade = User.new(last_name: "Sito", first_name: "Jaxa", email: "blindfoldedbutstillwinning@enterprise.com", photo_url: "https://vignette2.wikia.nocookie.net/memoryalpha/images/d/df/Sito_jaxa.jpg/revision/latest?cb=20141207024353&path-prefix=en")
    assert student_grade.save!

    course_student = CourseStudent.create(student: student_grade, student_id: student_grade.id, course_id: @course.id)
    assert course_student.save!

    assignment_user = AssignmentGrade.create(assignment_id: @assignment.id, course_student_id: course_student.student_id)
    assert assignment_user.save!

    assert student_grade.id == course_student.student_id

    assert course_student.student_id == assignment_user.course_student_id

    assert assignment_user.course_student_id == student_grade.id
  end

  #B-Test-16
  def test_that_a_course_has_many_students_through_courses_course_students
    student = User.create(last_name: "Ro", first_name: "Laren", email: "solongandthanksforallthefeds@maquis.com", photo_url: "https://www.maquis.com/raiders/ro_laren.jpg")
    assert student.persisted?
    assert student.save!

    student1 = User.create(last_name: "Zek", first_name: "Grand Nagus", email: "ruleofacquisition32@latinum.com", photo_url: "https://www.latinum.com/aintizekksy.png")
    assert student1.persisted?
    assert student.save!

    CourseStudent.create(student: student, course: @course)

    CourseStudent.create(student: student1, course: @course)

    assert_equal 2, @course.students.length
  end

  #B-Test-17
  def test_that_a_course_is_tied_to_its_primary_instructor
  # The primary instructor is the one who is referenced by a course_instructor which has its primary flag set to true.
    course_primary_inst = Course.create(name: "I'm the only instructor", course_code: "ncc5678")
    assert course_primary_inst.persisted?
    assert course_primary_inst.save!

    primary_inst_user = User.new(last_name: "Noonien Singh", first_name: "Khan", email: "gonnablowuptheenterprise@outcast.net", photo_url: "https://heresmypicsuckas.png")

    primary_inst = CourseInstructor.create(course: course_primary_inst, instructor: primary_inst_user, primary: true)
    assert primary_inst.persisted?
    assert primary_inst.save!

    assert course_primary_inst.primary_instructor == primary_inst_user
  end

  #B Epic Mode
  #B-Test-18
  def test_that_a_courses_students_are_ordered_by_last_name_first_name
    user3 = User.find_or_create_by(last_name: "Of Nine", first_name: "Seven", email: "iresisted@voyager.com", photo_url: "https://www.voyager.com/personnel/biotech.png")
    assert user3.persisted?
    assert user3.save!

    user2 = User.find_or_create_by(last_name: "Paris", first_name: "Tom", email: "haveyouseenmeflythisthing@voyager.com", photo_url: "https://www.voyager.com/personnel/tomparis.jpg")
    assert user2.persisted?
    assert user2.save!

    user1 = User.find_or_create_by(last_name: "Torres",  first_name: "B'elanna", email: "batlethtotheeyes@voyager.com", photo_url:"https://www.voyager.com/personnel/imarriedtommy.jpg")
    assert user1.persisted?
    assert user1.save!

    course = Course.create(name: "Sorting for blockheads", course_code: "ncc5985")

    course.students << user1
    course.students << user2
    course.students << user3

    assert course.students.first ==  user3
  end

  def test_that_child_lessons_are_sorted_by_their_ids
    parent_lesson = Lesson.find_or_create_by!(name: "Testing child lessons are sorted by their IDs")
    assert parent_lesson.persisted?
    assert parent_lesson.save!

    child_lesson1 = Lesson.create(name: "Child Lesson 1", parent_lesson_id: parent_lesson.id)
    assert child_lesson1.persisted?
    assert child_lesson1.save!

    child_lesson2 = Lesson.create(name: "Child Lesson 2", parent_lesson_id: parent_lesson.id)
    assert child_lesson2.persisted?
    assert child_lesson2.save!

    child_lesson3 = Lesson.create(name: "Child Lesson 3", parent_lesson_id: parent_lesson.id)
    assert child_lesson3.persisted?
    assert child_lesson3.save!

    parent_lesson.child_lessons << child_lesson3
    parent_lesson.child_lessons << child_lesson1
    parent_lesson.child_lessons << child_lesson2

    assert parent_lesson.child_lessons.first == child_lesson1

    # sort = []
    # sort << child_lesson3
    # sort << child_lesson1
    # sort << child_lesson2
    # sort << parent_lesson
    # refute sort[0] == child_lesson1
    #
    # sort.sort!
    # assert sort[1] == child_lesson1

  end

end
