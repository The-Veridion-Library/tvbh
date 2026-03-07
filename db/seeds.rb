Badge.find_or_create_by!(name: 'First Find') do |b|
  b.description = 'Found your first book!'
  b.icon        = '📖'
  b.threshold   = 1
  b.badge_type  = 'finds'
  b.seeded      = true
end

Badge.find_or_create_by!(name: 'Book Worm') do |b|
  b.description = 'Found 10 books!'
  b.icon        = '🐛'
  b.threshold   = 10
  b.badge_type  = 'finds'
  b.seeded      = true
end

Badge.find_or_create_by!(name: 'Librarian') do |b|
  b.description = 'Hidden 5 books for others to find!'
  b.icon        = '📚'
  b.threshold   = 5
  b.badge_type  = 'hidden'
  b.seeded      = true
end

Badge.find_or_create_by!(name: 'Centurion') do |b|
  b.description = 'Earned 100 points!'
  b.icon        = '🏆'
  b.threshold   = 100
  b.badge_type  = 'points'
  b.seeded      = true
end