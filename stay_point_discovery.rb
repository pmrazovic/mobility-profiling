require './st_dbscan'
require 'csv'

stay_points_csv = File.open("stay_points.csv", 'w')

(0..181).each do |user_id|

  trajectories = []

  files = Dir.glob("../geolife_trajectories/Data/#{user_id.to_s.rjust(3,'0')}/Trajectory/*.plt").sort
  files.each do |file|
    row_num = 0
    counter = 0
    trajectory_points = []
    CSV.foreach(file) do |row|
      row_num += 1
      next if row_num <= 6 
      trajectory_points << StayPointProcessor::TrajectoryPoint.new(counter, row[0].to_f, row[1].to_f, DateTime.strptime("#{row[5]} #{row[6]}", '%Y-%m-%d %H:%M:%S'), false)
      counter += 1
    end
    trajectories << trajectory_points
  end

  start = Time.now
  stay_point_clusters = []
  trajectories.each { |trajectory| stay_point_clusters += StayPointProcessor.run(trajectory, 50, 20) }
  finish = Time.now
  puts "Stay points discovery for User \##{user_id.to_s.rjust(3,'0')}: #{finish - start}"

  stay_point_clusters.each do |cluster|
    stay_points_csv.puts [user_id, cluster.lat_mean, cluster.lon_mean, cluster.arrival, cluster.departure, cluster.time_span].join(',')
  end

end