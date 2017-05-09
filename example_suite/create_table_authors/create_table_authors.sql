DROP TABLE IF EXISTS attes_example_authors;

--
-- The table 'attes_example_authors' records information about authors.
--
--     i_id         : The author's ID, serves as a primary key.
--     s_lastname   : The author's lastname.
--     s_firstname  : The author's firstname.
--     s_nationality: The author's nationality.
--     i_year_birth : The author's year of birth (or NULL is unknown).
--     i_year_death : The author's year of death (or NULL is unknown).
--
CREATE TABLE attes_example_authors
(
    i_id          INT AUTO_INCREMENT,
    s_lastname    VARCHAR(128) NOT NULL,
    s_firstname   VARCHAR(128) NOT NULL,
    s_nationality VARCHAR(32),
    i_year_birth  INT,
    i_year_death  INT,

    PRIMARY KEY(i_id),
    UNIQUE(s_lastname, s_firstname, i_year_birth)
)
ENGINE          = INNODB
DEFAULT CHARSET = utf8
COLLATE         = utf8_bin
;
