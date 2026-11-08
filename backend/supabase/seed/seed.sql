-- Development seed data (fake data only, never run in production).
-- Inserted during local development to populate formulas, subject categories, and initial options.

insert into public.formula_entries (stream, subject, topic, title, latex, description, status)
values
  ('mathematics', 'Combined Mathematics', 'Trigonometry', 'Double Angle Formula', '\sin(2\theta) = 2\sin(\theta)\cos(\theta)', 'Standard double-angle sine formula', 'published'),
  ('mathematics', 'Combined Mathematics', 'Calculus', 'Derivative of \tan(x)', '\frac{d}{dx}\tan(x) = \sec^2(x)', 'Standard trigonometric derivative', 'published'),
  ('science', 'Physics', 'Mechanics', 'Linear Motion Equation', 'v^2 = u^2 + 2as', 'Uniform accelerated linear motion', 'published'),
  ('science', 'Physics', 'Electricity', 'Ohm''s Law', 'V = IR', 'Voltage, current and resistance relation', 'published'),
  ('technology', 'Engineering Tech', 'Electronics', 'Resistors in Parallel', '\frac{1}{R_p} = \frac{1}{R_1} + \frac{1}{R_2}', 'Equivalent resistance for parallel circuit', 'published');
