-- users table
CREATE TABLE users (
id VARCHAR (40) NOT NULL PRIMARY KEY ,
email VARCHAR (50) NOT NULL UNIQUE ,
user_name VARCHAR (40) NOT NULL
) ;
-- categories table
CREATE TABLE categories (
category_id VARCHAR (8) NOT NULL PRIMARY KEY ,
category_name VARCHAR (50) NOT NULL UNIQUE ,
description VARCHAR (150)
) ;
-- ingredients table
CREATE TABLE ingredients (
ingredient_id INT NOT NULL PRIMARY KEY ,
name VARCHAR (50) NOT NULL UNIQUE ,
category_id VARCHAR (8) NOT NULL ,
FOREIGN KEY ( category_id ) REFERENCES categories ( category_id ) ON DELETE
CASCADE
) ;
-- recipes table
CREATE TABLE recipes (
recipe_id INT NOT NULL PRIMARY KEY ,
title VARCHAR (100) NOT NULL ,
description VARCHAR (150) ,
serving_size VARCHAR (50) ,
cooking_time INT NOT NULL ,
calories_per_serving DECIMAL (6 , 2) NOT NULL ,
protein_per_serving DECIMAL (6 , 2) NOT NULL ,
carbs_per_serving DECIMAL (6 , 2) NOT NULL ,
fat_per_serving DECIMAL (6 , 2) NOT NULL
) ;
-- recipe_ingredients table
CREATE TABLE recipe_ingredients (
recipe_id INT NOT NULL AUTO INCREMENT ,
ingredient_id INT NOT NULL ,
quantity DECIMAL (6 , 2) ,
unit VARCHAR (40) ,
PRIMARY KEY ( recipe_id , ingredient_id ) ,
FOREIGN KEY ( recipe_id ) REFERENCES recipes ( recipe_id ) ON DELETE
CASCADE ,
FOREIGN KEY ( ingredient_id ) REFERENCES ingredients ( ingredient_id ) ON
DELETE CASCADE
) ;
-- diets table
CREATE TABLE diets (
diet_id VARCHAR (8) NOT NULL PRIMARY KEY ,
diet_name VARCHAR (40) NOT NULL UNIQUE ,
description VARCHAR (150) ,
diet_type INT NOT NULL
) ;
-- diets_type_1 table
CREATE TABLE diets_type_1 (
diet_id VARCHAR (8) NOT NULL ,
per_meal_calorie_min DECIMAL (6 , 2) NOT NULL ,
per_meal_calorie_max DECIMAL (6 , 2) NOT NULL ,
per_meal_protein_min DECIMAL (6 , 2) NOT NULL ,
per_meal_protein_max DECIMAL (6 , 2) NOT NULL ,
per_meal_carbs_min DECIMAL (6 , 2) NOT NULL ,
per_meal_carbs_max DECIMAL (6 , 2) NOT NULL ,
per_meal_fat_min DECIMAL (6 , 2) NOT NULL ,
per_meal_fat_max DECIMAL (6 , 2) NOT NULL ,
FOREIGN KEY ( diet_id ) REFERENCES diets ( diet_id ) ON DELETE CASCADE
) ;
-- diets_type_2 table
CREATE TABLE diets_type_2 (
diet_id VARCHAR (8) NOT NULL ,
category_id VARCHAR (8) NOT NULL ,
PRIMARY KEY ( diet_id , category_id ) ,
FOREIGN KEY ( diet_id ) REFERENCES diets ( diet_id ) ON DELETE CASCADE
10
FOREIGN KEY ( category_id ) REFERENCES categories ( category_id ) ON DELETE
CASCADE
) ;
-- user_allergies table
CREATE TABLE user_allergies (
user_id VARCHAR (40) NOT NULL ,
ingredient_id INT NOT NULL ,
PRIMARY KEY ( user_id , ingredient_id ) ,
FOREIGN KEY ( user_id ) REFERENCES users ( id ) ON DELETE CASCADE ,
FOREIGN KEY ( ingredient_id ) REFERENCES ingredients ( ingredient_id ) ON
DELETE CASCADE
) ;
-- user_diets table
CREATE TABLE user_diets (
user_id VARCHAR (40) NOT NULL ,
diet_id VARCHAR (8) NOT NULL ,
PRIMARY KEY ( user_id , diet_id ) ,
FOREIGN KEY ( user_id ) REFERENCES users ( id ) ON DELETE CASCADE ,
FOREIGN KEY ( diet_id ) REFERENCES diets ( diet_id ) ON DELETE CASCADE
) ;
-- recipe_directions table
CREATE TABLE recipe_directions (
recipe_id INT NOT NULL ,
step_order INT NOT NULL ,
step_description VARCHAR (150) ,
time_duration_minutes INT ,
PRIMARY KEY ( recipe_id , step_order ) ,
FOREIGN KEY ( recipe_id ) REFERENCES recipes ( recipe_id ) ON DELETE
CASCADE
) ;




CREATE OR REPLACE VIEW user_allergy_safe_recipes AS
SELECT u . id AS user_id , u . user_name , r . recipe_id , r . title
FROM users u
CROSS JOIN recipes r
WHERE NOT EXISTS (
SELECT 1
FROM recipe_ingredients ri
JOIN user_allergies ua ON ri . ingredient_id = ua . ingredient_id
WHERE ri . recipe_id = r . recipe_id
AND ua . user_id = u . id
) ;
SELECT * FROM user_allergy_safe_recipes ;





CREATE OR REPLACE VIEW user_categorical_diet_recipes AS
SELECT
u . id AS user_id ,
u . user_name ,
r . recipe_id ,
r . title
FROM
users u
CROSS JOIN recipes r
WHERE
-- Either the user has no type 2 diets
NOT EXISTS (
SELECT 1
FROM user_diets ud
JOIN diets d ON ud . diet_id = d . diet_id AND d . diet_type = 2
WHERE ud . user_id = u . id
)
-- Or recipe doesn ’ t contain any restricted ingredients for this
user
OR NOT EXISTS (
SELECT 1
FROM recipe_ingredients ri
JOIN ingredients i ON ri . ingredient_id = i . ingredient_id
JOIN diets_type_2 dt2 ON i . category_id = dt2 . category_id
JOIN user_diets ud ON dt2 . diet_id = ud . diet_id
WHERE ri . recipe_id = r . recipe_id
AND ud . user_id = u . id
AND ud . diet_id IN ( SELECT diet_id FROM diets WHERE diet_type =
2)
) ;
SELECT * FROM user_categorical_diet_recipes ;


CREATE OR REPLACE VIEW user_nutritional_diet_recipes AS
WITH use r_nutritional_requirements AS (
SELECT
u . id AS user_id ,
u . user_name ,
MAX ( dt1 . per_meal_calorie_min ) AS max_calorie_min ,
MIN ( dt1 . per_meal_calorie_max ) AS min_calorie_max ,
MAX ( dt1 . per_meal_protein_min ) AS max_protein_min ,
MIN ( dt1 . per_meal_protein_max ) AS min_protein_max ,
MAX ( dt1 . per_meal_carbs_min ) AS max_carbs_min ,
MIN ( dt1 . per_meal_carbs_max ) AS min_carbs_max ,
MAX ( dt1 . per_meal_fat_min ) AS max_fat_min ,
MIN ( dt1 . per_meal_fat_max ) AS min_fat_max ,
CASE WHEN COUNT ( d . diet_id ) > 0 THEN TRUE ELSE FALSE END AS
has_type1_diet
FROM
users u
LEFT JOIN user_diets ud ON u . id = ud . user_id
LEFT JOIN diets d ON ud . diet_id = d . diet_id AND d . diet_type = 1
LEFT JOIN diets_type_1 dt1 ON d . diet_id = dt1 . diet_id
GROUP BY
u . id
)
SELECT
unr . user_id AS user_id ,
unr . user_name ,
r . recipe_id ,
r . title
FROM
user_nutritional_requirements unr
CROSS JOIN recipes r
WHERE
-- If user has type 1 diets , apply restrictions , otherwise include
all recipes
( unr . has_type1_diet = FALSE ) OR
(
r . calories_per_serving BETWEEN unr . max_calorie_min AND unr .
min_calorie_max
AND r . protein_per_serving BETWEEN unr . max_protein_min AND unr .
min_protein_max
AND r . carbs_per_serving BETWEEN unr . max_carbs_min AND unr .
min_carbs_max
AND r . fat_per_serving BETWEEN unr . max_fat_min AND unr .
min_fat_max
) ;
SELECT * FROM user_nutritional_diet_recipes ;





CREATE OR REPLACE FUNCTION get_compatible_recipes ( p_user_id UUID )
RETURNS TABLE (
recipe_id INT ,
title VARCHAR ,
allergy_safe BOOLEAN ,
nutritional_compliant BOOLEAN ,
categorical_compliant BOOLEAN
) AS $$
BEGIN
RETURN QUERY
SELECT
r . recipe_id ,
r . title ,
( uasr . recipe_id IS NOT NULL ) AS allergy_safe ,
( undr . recipe_id IS NOT NULL ) AS nutritional_compliant ,
( ucdr . recipe_id IS NOT NULL ) AS categorical_compliant
FROM recipes r
LEFT JOIN user_allergy_safe_recipes uasr
ON r . recipe_id = uasr . recipe_id AND uasr . user_id = p_user_id
LEFT JOIN user_nutritional_diet_recipes undr
ON r . recipe_id = undr . recipe_id AND undr . user_id = p_user_id
LEFT JOIN user_categorical_diet_recipes ucdr
ON r . recipe_id = ucdr . recipe_id AND ucdr . user_id = p_user_id
WHERE
uasr . recipe_id IS NOT NULL OR
undr . recipe_id IS NOT NULL OR
ucdr . recipe_id IS NOT NULL ;
END ;
$$ LANGUAGE plpgsql ;
