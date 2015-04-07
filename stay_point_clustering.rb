require 'csv'
require './optics'
require "./hierarchical_clustering_processor"

# reading predescovered stay points
rows = []
CSV.foreach('./stay_points.csv') do |row|
  rows << [row[0].to_i ,row[1].to_f, row[2].to_f, DateTime.iso8601(row[3]), DateTime.iso8601(row[4]), row[5].to_f]
end
stay_points = NArray.to_na(rows)

# using NArray data structures
coordinates = NArray.to_na(rows.collect{|r| [r[1],r[2]]})

# Running OPTICS clustering
puts "Running OPTICS clustering..."
start = Time.now
rd, cd, order = OPTICS.run(coordinates,3)
finish = Time.now
puts "Finished in #{(finish - start).round(2)} seconds"
puts "-------------------------------------"

# Inputs for cluster hierarchy processor
r_plot = rd[order]
r_order = NArray.to_na(order)

# Contructing cluster hierarchy
puts "Constructing cluster hierarchy..."
start = Time.now
framework = HierarchicalClusteringProcessor.run(r_plot, r_order, stay_points)
finish = Time.now
puts "Finished in #{(finish - start).round(2)} seconds"
puts "-------------------------------------"

# Initialize empty user structures wrt framework
users = []
(0..181).each{ |idx| users << [] }
framework.each_with_index do |level,level_idx|
  users.each{|u| u << [] }
  level.each_with_index do |cluster, cluster_idx|
    users.each{|u| u[level_idx] << [] }
  end
end

# Populate user structures
framework.each_with_index do |level,level_idx|
  level.each_with_index do |cluster, cluster_idx|
    cluster.each do |point|
      users[point[0]][level_idx][cluster_idx] << point[1..-1]
    end
  end
end

# Generating feature vectors for each level
feature_vectors = []
framework.each_with_index do |level,level_idx|
  feature_vectors << []
  users.each do |user|
    user_vector = []
    user[level_idx].each do |cluster|
      sum = 0
      cluster.each{|p| sum += p[-1] }
      user_vector << sum
    end
    feature_vectors[level_idx] << user_vector
  end
end

def cosine_similarity(user_idx,a,m)
  dot_prods = (m*a).sum(0)
  magn_prods = NMath.sqrt((m**2).sum(0))*NMath.sqrt((a**2).sum(0))
  # preventing devision by zero
  zero_positions = magn_prods.eq(0).where
  sim_vector = dot_prods/magn_prods
  sim_vector[zero_positions] = 0.0
  sim_vector[user_idx] = 1.0
  return sim_vector
end

similarity_matrices = []
feature_vectors.each do |level_feature_matrix|
  level_sim_matrix = []
  level_feature_matrix.each_with_index do |feature_vector, feature_vector_idx|
    level_sim_matrix << cosine_similarity(feature_vector_idx, NArray.to_na(feature_vector), NArray.to_na(level_feature_matrix))
  end
  similarity_matrices << NArray.to_na(level_sim_matrix)
end

accumulated_sim_matrix = similarity_matrices[0]
weight = 1
similarity_matrices.each_with_index do |level_sim_matrix, idx|
  next if idx == 0
  accumulated_sim_matrix += level_sim_matrix*(2**idx)
  weight += 2**idx
end
accumulated_sim_matrix /= weight

puts similarity_matrices.inspect
puts accumulated_sim_matrix.inspect

# Printing in Matlab file
def print_level(level, x)
  file = File.open("result.m","w")
  file.puts "\nformat long"
  file.puts "hold all"
  level.each do |cluster|
    file.puts "lat = [#{cluster.to_a.collect{|p| p[1]}.join(" ")}]"
    file.puts "lon = [#{cluster.to_a.collect{|p| p[2]}.join(" ")}]"
    file.puts "k=convhull(lon,lat);"
    file.puts "plot(lon,lat,'.','MarkerSize',20)"
    file.puts "plot(lon(k),lat(k),'-b')"
  end
  file.puts "plot_google_map"
end

# Comparing two users using Matlab plot

# file = File.open("result.m","w")
# file.puts "\nformat long"
# file.puts "hold all"

# lat_1 = []
# lon_1 = []
# users[0][0].each do |cluster|
#   lat_1 << cluster.to_a.collect{|p| p[0]}
#   lon_1 << cluster.to_a.collect{|p| p[1]}
# end

# lat_2 = []
# lon_2 = []
# users[3][0].each do |cluster|
#   lat_2 << cluster.to_a.collect{|p| p[0]}
#   lon_2 << cluster.to_a.collect{|p| p[1]}
# end

# file.puts "lat = [#{lat_1.join(" ")}]"
# file.puts "lon = [#{lon_1.join(" ")}]"
# file.puts "plot(lon,lat,'.','MarkerSize',20)"
# file.puts "lat = [#{lat_2.join(" ")}]"
# file.puts "lon = [#{lon_2.join(" ")}]"
# file.puts "plot(lon,lat,'*','MarkerSize',10)"
# file.puts "plot_google_map"

# Matlab preview
# print_level(framework[0],stay_points)