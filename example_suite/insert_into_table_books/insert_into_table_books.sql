INSERT INTO attes_example_books VALUE(DEFAULT, 'brave new world', 1, 'english', 1932);
INSERT INTO attes_example_books VALUE(DEFAULT, 'to kill a mockingbird', 2, 'english', 1960);
INSERT INTO attes_example_books VALUE(DEFAULT, 'nineteen eighty-four', 3, 'english', 1949);

--
-- Should return: ERROR 1062 (23000): Duplicate entry 'brave new world-1'.
--
INSERT INTO attes_example_books VALUE(DEFAULT, 'brave new world', 1, 'english', 1932);
--
-- Should return: ERROR 1062 (23000): Duplicate entry '2' for key 'PRIMARY'
--
INSERT INTO attes_example_books VALUE(2, 'go set a watchman', 2, 'english', 2015);
--
-- Should return: ERROR 1452 (23000): Cannot add or update a child row.
--
INSERT INTO attes_example_books VALUE(5, 'crime and punishment', 5, 'russian', 1866);
--
-- This should return 3.
--
SELECT COUNT(*) FROM attes_example_books;
