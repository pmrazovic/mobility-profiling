require 'csv'
require './optics'
require "./hierarchical_clustering_processor"
require "./hosvd"

def construct_tensor_hierarchy(rows)
  stay_points = NArray.to_na(rows)

  # using NArray data structures
  coordinates = NArray.to_na(rows.collect{|r| [r[1],r[2]]})

  # Running OPTICS clustering
  puts "\nRunning OPTICS clustering..."
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
  temp_tensors = Array.new
  # constructing tensors (user x cluster x time_frame)
  framework.each do |level|
    tensor = NArray.float(level.size,182,8)
    level.each_with_index do |cluster, cluster_idx|
      cluster[:points].each do |stay_point|
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

    temp_tensors << tensor
  end

  tensors = Array.new
  framework.each_with_index do |level,level_idx|
    tensor = NArray.float(level.size,182,8)
    level.each_with_index do |cluster, cluster_idx|
      (0..181).each do |user_idx|
        (0..7).each do |time_frame_idx|
          if temp_tensors[level_idx][true,user_idx,time_frame_idx].sum == 0
            personal_importance = 0.0
          else
            personal_importance = temp_tensors[level_idx][cluster_idx,user_idx,time_frame_idx] / temp_tensors[level_idx][true,user_idx,time_frame_idx].sum
          end
          if temp_tensors[level_idx][cluster_idx,true,time_frame_idx].sum == 0 
            collective_importance = 0.0
          else
            collective_importance = temp_tensors[level_idx][cluster_idx,user_idx,time_frame_idx] / temp_tensors[level_idx][cluster_idx,true,time_frame_idx].sum
          end
          tensor[cluster_idx,user_idx,time_frame_idx] = 0.7*personal_importance + 0.3*collective_importance
        end
      end
    end
    tensors << tensor
  end

  finish = Time.now
  puts "Finished in #{(finish - start).round(2)} seconds"
  puts "-------------------------------------"

  return [framework, temp_tensors, tensors]
end

def cosine_similarity(user_vector_1, user_vector_2)
  square_sum = Math.sqrt((user_vector_1**2).sum) * Math.sqrt((user_vector_2**2).sum)
  return 0.0 if square_sum == 0
  return (user_vector_1*user_vector_2).sum / square_sum
end

def construct_user_similarity_matrix(tensors)

  # Constructing similarity matrix
  puts "Constructing similarity matrix..."
  start = Time.now

  similarity_matrices = []
  accumulated_similarity_matrix = NArray.float(182,182)
  weights = 0.0
  tensors.each_with_index do |tensor,level_idx|
    similarity_matrix = NArray.float(182,182)
    (0..181).each do |user_i|
      (0..181).each do |user_j|
        if user_i == user_j
          similarity_matrix[user_j,user_i] = 0.0
        else
          similarity_matrix[user_j,user_i] = cosine_similarity(tensor[true,user_i,true],tensor[true,user_j,true])
        end
        accumulated_similarity_matrix[user_j,user_i] += similarity_matrix[user_j,user_i]*(2**level_idx)
      end
    end
    weights += 2**level_idx
    similarity_matrices << similarity_matrix
  end

  accumulated_similarity_matrix = accumulated_similarity_matrix / weights

  finish = Time.now
  puts "Finished in #{(finish - start).round(2)} seconds"
  puts "-------------------------------------"

  return accumulated_similarity_matrix

end

# reading predescovered stay points
rows = []
CSV.foreach('./stay_points.csv') do |row|
  rows << [row[0].to_i ,row[1].to_f, row[2].to_f, DateTime.iso8601(row[3]), DateTime.iso8601(row[4]), row[5].to_f]
end

original_framework, temp_tensors, tensors = construct_tensor_hierarchy(rows)
original_similarity_matrix = construct_user_similarity_matrix(temp_tensors)

# Printing discovered hierarchy
puts "Constructed #{original_framework.size} level(s) in stay region hierarchy"
original_framework.each_with_index do |level,level_idx|
  puts "\nLevel \##{level_idx}: #{level.size} stay region(s)"
  level.each_with_index do |cluster,cluster_idx|
    puts "Stay region \##{cluster_idx}: #{cluster[:points].size} stay points"
  end
end

while true
  
  puts "\nChoose level (0-#{original_framework.size-1}):"
  chosen_level = gets.chomp.to_i
  puts "\nChoose stay region (0-#{original_framework[chosen_level].size-1}):"
  chosen_cluster = gets.chomp.to_i
  puts "\nChoose time slot (0-7):\n0) 0-3\n1) 3-6\n2) 6-9 \n3) 9-12\n4) 12-15\n5) 15-18\n6) 18-21\n7) 21-0"
  chosen_time_slot = gets.chomp.to_i

  node = original_framework[chosen_level][chosen_cluster]
  user_scores = NArray.float(182)
  acc_weight = 0
  while !node.nil?
    user_scores += tensors[node[:level_idx]][node[:cluster_idx],true,chosen_time_slot]*(2**node[:level_idx])
    acc_weight += 2**node[:level_idx]
    node = node[:parent_node]
  end

  user_scores /= acc_weight
  top_users = user_scores.to_a.map.with_index.sort.reverse.map(&:last).take(10)
  top_user_scores = user_scores.to_a.sort.reverse.take(10)

  puts "\nRank\tUser No.\tScore (0 - 100 %)\n----------------------------------------------"
  top_users.each_with_index do |user,idx|
    puts "#{idx+1}. \tUser \##{user} \t#{(top_user_scores[idx]*100).round(5)} %"
  end

  puts "\nSimilarity matrix ------------------------------"
  top_sims = original_similarity_matrix[[top_users],[top_users]]
  (0..9).each do |idx|
    puts top_sims[true,idx].to_a.collect{|s| s.round(5)}.join("  ")
  end

  # Comparing first 4 users using Matlab plot

  file = File.open("result.m","w")
  file.puts "\nformat long"
  file.puts "figure"

  top_users.take(4).each_with_index do |top_user,idx|
    node = original_framework[chosen_level][chosen_cluster]
    file.puts "subplot(2, 2, #{idx+1})"
    file.puts "hold on"
    while !node.nil?
      file.puts "lat = [#{node[:points].collect{|p| p[1]}.join(" ")}]"
      file.puts "lon = [#{node[:points].collect{|p| p[2]}.join(" ")}]"
      file.puts "k=convhull(lon,lat);"
      file.puts "plot(lon(k),lat(k),'-b')"
      file.puts "lat = [#{node[:points].select{|p| p[0] == top_user}.collect{|p| p[1]}.join(" ")}]"
      file.puts "lon = [#{node[:points].select{|p| p[0] == top_user}.collect{|p| p[2]}.join(" ")}]"
      file.puts "plot(lon,lat,'.','MarkerSize',10)"
      node = node[:parent_node]
    end
    file.puts "title('#{idx+1}.) User #{top_user}: #{(top_user_scores[idx]*100).round(5)}')"
    file.puts "plot_google_map"
    file.puts "hold off"
  end

  file.close

end


# # Running HOSVD
# puts "Running HOSVD..."
# start = Time.now
# tensors_prime = []
# tensors.each{|tensor| tensors_prime << HOSVD.run(tensor)}
# finish = Time.now
# puts "Finished in #{(finish - start).round(2)} seconds"
# puts "------------------------------------------------------------------------------------"

# Interaction with user

puts "\nChoose percentage of test data\n0) 5%\n1) 10%\n2) 20%"
case gets.chomp
when '0'
  test_data_size = 0.05
when '1'
  test_data_size = 0.1
else
  test_data_size = 0.2
end

limit_date = rows.sort{|x,y| x[3] <=> y[3]}[(rows.size*(1-test_data_size)).ceil][3]
train_rows = rows.select{|row| row[3] < limit_date}

train_framework, train_tensors = construct_tensor_hierarchy(train_rows)
train_similarity_matrix = construct_user_similarity_matrix(train_tensors)

puts (original_similarity_matrix - train_similarity_matrix).inspect

query_points = []
train_framework.each_with_index do |level, level_idx|
  level.each_with_index do |cluster, cluster_idx|
    if cluster[:children_nodes].empty?
      point = cluster[:points].shuffle.first
      query_points << {:lat => point[1], :lon => point[2], :train => {:level => level_idx, :cluster => cluster_idx}}
    end
  end
end

query_points.each do |query_point|
  original_framework.each_with_index do |level,level_idx|
    level.each_with_index do |cluster, cluster_idx|
      if cluster[:children_nodes].empty?
        point = cluster[:points].select{|p| p[1] == query_point[:lat] && p[2] == query_point[:lon]}.first
        unless point.nil?
          query_point[:original] = {:level => level_idx, :cluster => cluster_idx}
        end
      end
    end
  end
end

query_points = query_points.select{|p| !p[:original].nil?}



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