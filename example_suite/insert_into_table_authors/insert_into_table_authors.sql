INSERT INTO attes_example_authors VALUE(DEFAULT, 'huxley', 'aldous', 'english', 1894, 1963);
INSERT INTO attes_example_authors VALUE(DEFAULT, 'lee', 'harper', 'american', 1926, 2016);
INSERT INTO attes_example_authors VALUE(DEFAULT, 'orwell', 'george', 'english', 1903, 1950);
INSERT INTO attes_example_authors VALUE(DEFAULT, 'camus', 'albert', 'french', 1913, 1960);
--
-- This should return: ERROR 1062 (23000): Duplicate entry 'camus-albert-1913'.
--
INSERT INTO attes_example_authors VALUE(DEFAULT, 'camus', 'albert', 'french', 1913, 0);
--
-- This should return: ERROR 1062 (23000): Duplicate entry '2' for key 'PRIMARY'.
--
INSERT INTO attes_example_authors VALUE(2, 'dostoyevsky', 'fyodor, mikhailovich', 'russian', 1821, 1881);
--
-- This should return 4.
--
SELECT COUNT(*) FROM attes_example_authors;
