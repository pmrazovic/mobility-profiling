require 'csv'
require './optics'
require "./hierarchical_clustering_processor"

# reading predescovered stay points
points = []
CSV.foreach('./stay_points.csv') do |row|
  points << [row[1].to_f, row[2].to_f]
end

# using NArray data structures
points = NArray.to_na(points)

# Running OPTICS clustering
puts "Running OPTICS clustering..."
start = Time.now
rd, cd, order = OPTICS.run(points,3)
finish = Time.now
puts "Finished in #{(finish - start).round(2)} seconds"
puts "-------------------------------------"

# Inputs for cluster hierarchy processor
r_plot = rd[order]
r_order = NArray.to_na(order)

# Contructing cluster hierarchy
puts "Constructing cluster hierarchy..."
start = Time.now
framework = HierarchicalClusteringProcessor.run(r_plot, r_order, points)
finish = Time.now
puts "Finished in #{(finish - start).round(2)} seconds"
puts "-------------------------------------"

# Printing in Matlab file
def print_level(level, x)
  file = File.open("result.m","w")
  file.puts "\nformat long"
  file.puts "hold all"
  level.each do |node|
    file.puts "lat = [#{x[true,node.points].to_a.collect{|p| p[0]}.join(" ")}]"
    file.puts "lon = [#{x[true,node.points].to_a.collect{|p| p[1]}.join(" ")}]"
    file.puts "k=convhull(lon,lat);"
    file.puts "plot(lon,lat,'.','MarkerSize',20)"
    file.puts "plot(lon(k),lat(k),'-b')"
  end
  file.puts "plot_google_map"
end

# Matlab preview
print_level(framework[1],points)