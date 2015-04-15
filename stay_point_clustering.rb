require 'csv'
require './optics'
require "./hierarchical_clustering_processor"
require "./hosvd"

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


# Constructing tensors
puts "Constructing tensors..."
start = Time.now

# Defining time frames for temporal analysis
time_frames = [ {:start => 0, :end => 3},
                {:start => 3, :end => 6},
                {:start => 6, :end => 9},
                {:start => 9, :end => 12},
                {:start => 12, :end => 15},
                {:start => 15, :end => 18},
                {:start => 18, :end => 21},
                {:start => 21, :end => 24} ]

# tensor array (one tensor per level - tensors[level_idx])
tensors = Array.new
# constructing tensors (user x cluster x time_frame)
framework.each do |level|
  tensor = NArray.float(level.size,182,8)
  level.each_with_index do |cluster, cluster_idx|
    cluster.each do |stay_point|
      # calculating stay time in each time frame
      time_frames.each_with_index do |time_frame, time_frame_idx|
        time = 0
        arrival = stay_point[3]
        departure = stay_point[4]

        # stays can happen through midnight which complicates calculation,
        # i.e. we need to split stay in two intervals (before and after midnight)
        stays = []
        if arrival.hour <= departure.hour
          stays << { :arrival => {:hour => arrival.hour, :min => arrival.min, :sec => arrival.sec}, 
                     :departure => {:hour => departure.hour, :min => departure.min, :sec => departure.sec} }
        elsif arrival.hour > departure.hour
          stays << { :arrival => {:hour => arrival.hour, :min => arrival.min, :sec => arrival.sec}, 
                     :departure => {:hour => 24, :min => 0, :sec => 0} }
          stays << { :arrival => {:hour => 0, :min => 0, :sec => 0}, 
                     :departure => {:hour => departure.hour, :min => departure.min, :sec => departure.sec} }
        end

        # calculating time per frame
        stays.each do |stay|
          if stay[:arrival][:hour] >= time_frame[:start] && stay[:departure][:hour] < time_frame[:end]
            time = (stay[:departure][:hour]*60 + stay[:departure][:min] + stay[:departure][:sec]/60.0) -
                   (stay[:arrival][:hour]*60 + stay[:arrival][:min] + stay[:arrival][:sec]/60.0)
          elsif stay[:arrival][:hour] < time_frame[:start] && stay[:departure][:hour] >= time_frame[:start] && stay[:departure][:hour] < time_frame[:end]
            time = (stay[:departure][:hour]*60 + stay[:departure][:min] + stay[:departure][:sec]/60.0) - time_frame[:start]*60
          elsif stay[:arrival][:hour] >= time_frame[:start] && stay[:arrival][:hour] < time_frame[:end] && stay[:departure][:hour] >= time_frame[:end]
            time = time_frame[:end]*60 - (stay[:arrival][:hour]*60 + stay[:arrival][:min] + stay[:arrival][:sec]/60.0) 
          elsif stay[:arrival][:hour] < time_frame[:start] && stay[:departure][:hour] >= time_frame[:end]
            time = (time_frame[:end] - time_frame[:start])*60
          end
        end

        # updating corresponding tensor value
        tensor[cluster_idx,stay_point[0],time_frame_idx] += time
      end
    end
  end

  tensors << tensor
end
puts "Finished in #{(finish - start).round(2)} seconds"
puts "-------------------------------------"

# Running HOSVD
puts "Running HOSVD..."
start = Time.now
tensors_prime = []
tensors.each{|tensor| tensors_prime << HOSVD.run(tensor)}
finish = Time.now
puts "Finished in #{(finish - start).round(2)} seconds"
puts "-------------------------------------"

# # Printing in Matlab file
# def print_level(level, x)
#   file = File.open("result.m","w")
#   file.puts "\nformat long"
#   file.puts "hold all"
#   level.each do |cluster|
#     file.puts "lat = [#{cluster.to_a.collect{|p| p[1]}.join(" ")}]"
#     file.puts "lon = [#{cluster.to_a.collect{|p| p[2]}.join(" ")}]"
#     file.puts "k=convhull(lon,lat);"
#     file.puts "plot(lon,lat,'.','MarkerSize',20)"
#     file.puts "plot(lon(k),lat(k),'-b')"
#   end
#   file.puts "plot_google_map"
# end

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