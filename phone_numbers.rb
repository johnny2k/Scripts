
if (ARGV.length == 0): puts("Usage: phone_numbers <areacode>")	
end

# Look up this area code on telcodata.us
areacode = ARGV[0].to_i

# Obtain a list of all the exchanges in the area code.
exchanges = `curl -N -s http://www.telcodata.us/search-area-code-exchange-detail?npa=#{areacode} | grep -E -o '(#{areacode}\-...)' |  awk -F \- '{print $1$2}' | uniq`

# Back to integers.
array = exchanges.scan(/\d{6}/).map { |c| c.to_i }

# Print the numbers.
for i in 0 .. array.length
  for j in 0 .. 9999 
    print array[i] * 10000 + j 
    puts "\n"
  end
end 
