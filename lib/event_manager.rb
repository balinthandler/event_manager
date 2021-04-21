require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'pry'



def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phonenumber(phone_number)
  clean = []
  phone_number.split('').each { |char|
    if /\d/.match(char) then clean << char end
    }
  joined = clean.join
  if /^1?\d{10}$/.match(joined)
    joined
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exists?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def best_hours(csv,column)
  hours = {}
  hours.default = 0

  csv.each { |row|
    time = Time.parse(row[column].split(' ')[1])
    hours[time.hour] += 1
  }
  csv.rewind
  hours_sorted = hours.sort_by { |key, value| value}.reverse
end

def best_days(csv,column)
  days = {}
  days.default = 0

  csv.each { |row|
    clean_date_array = row[column].split(' ')[0].split("/")
    clean_date_array[2] = "20" + clean_date_array[2]
    date_str = clean_date_array.join('/')
    wday = Date.strptime(date_str,"%m/%d/%Y").wday
    dayname = Date::DAYNAMES[wday]
    days[dayname] += 1
    
  }
  csv.rewind
  days_sorted = days.sort_by { |key, value| value}.reverse
end

def show_best_days(array)
  puts "Busy days in registration:"
  
  3.times {|i| 
    puts "#{i+1}. Day: #{array[i][0]}. Registration count on #{array[i][0]}s: #{array[i][1]}"
  }

end

def show_best_hours(array)
  puts "Busy hours in registration:"
  3.times {|i| 
    puts "#{i+1}. Hour: #{array[i][0]}. Registration count in that hour: #{array[i][1]}"
  }
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)



template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

show_best_hours(best_hours(contents, :regdate))
show_best_days(best_days(contents, :regdate))


contents.each do |row|
  id = row[0]
  name = row[:first_name]
  
  zipcode = clean_zipcode(row[:zipcode])

  phone_number = clean_phonenumber(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

