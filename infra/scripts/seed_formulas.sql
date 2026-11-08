insert into public.formula_entries (stream, subject, topic, title, latex, description, status)
values
  ('Physical Science', 'Mathematics', 'Algebra', 'Quadratic Formula', 'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}', 'Finds roots of quadratic polynomial ax^2 + bx + c = 0', 'published'),
  ('Physical Science', 'Physics', 'Mechanics', 'Newton''s Second Law', 'F = m \cdot a', 'Relates net force on an object to its mass and acceleration', 'published'),
  ('Biological Science', 'Chemistry', 'Physical Chemistry', 'Ideal Gas Law', 'P \cdot V = n \cdot R \cdot T', 'Equation of state for a hypothetical ideal gas', 'published'),
  ('Physical Science', 'Physics', 'Electricity', 'Ohm''s Law', 'V = I \cdot R', 'Relationship between voltage, current, and resistance', 'published'),
  ('Physical Science', 'Physics', 'Mechanics', 'Kinetic Energy', 'KE = \frac{1}{2}m v^2', 'Work needed to accelerate a body of mass m to velocity v', 'published'),
  ('Physical Science', 'Mathematics', 'Geometry', 'Pythagorean Theorem', 'a^2 + b^2 = c^2', 'Fundamental relation among sides of a right triangle', 'published')
on conflict do nothing;
