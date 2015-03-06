module StayPointProcessor
  TrajectoryPoint = Struct.new(:idx, :lat, :lon, :time, :processed)
  Cluster = Struct.new(:points, :arrival, :departure, :time_span, :lat_mean, :lon_mean)
  public

    def self.run(trajectory_points, eps, min_time)
      clusters = []
      trajectory_points.each_with_index do |p,index|
        if !p.processed
          p.processed = true
          neighbours = linear_neighborhood(trajectory_points,p,eps)

          time_span = 0
          if neighbours.length >= 2
            time_span = (neighbours.last.time - neighbours.first.time).abs
          end

          if time_span*24*60 >= min_time   # if p is core point
            new_cluster = []
            neighbours.each do |n|
              n.processed = true          
              new_cluster << n
            end

            clusters << Cluster.new( new_cluster, new_cluster.first.time, new_cluster.last.time,
                                     (new_cluster.last.time - new_cluster.first.time)*24.0*60.0,
                                     new_cluster.inject(0.0){ |sum, el| sum += el.lat } / new_cluster.size,
                                     new_cluster.inject(0.0){ |sum, el| sum + el.lon } / new_cluster.size)

            # Handling noise (merge last two cluster if they are density joinable)
            if density_joinable(clusters[-1].points,clusters[-2].points,eps)
              clusters[-2].points += clusters[-1].points
              clusters[-2].departure = clusters[-1].departure
              clusters[-2].time_span = (clusters[-1].departure - clusters[-2].arrival)*24.0*60.0
              clusters[-2].lat_mean = (clusters[-2].lat_mean * clusters[-2].points.size + clusters[-1].lat_mean * clusters[-1].points.size) / (clusters[-2].points.size + clusters[-1].points.size)
              clusters[-2].lon_mean = (clusters[-2].lon_mean * clusters[-2].points.size + clusters[-1].lon_mean * clusters[-1].points.size) / (clusters[-2].points.size + clusters[-1].points.size)
              clusters.pop
            end unless clusters.size < 2
          end

        end
      end

      return clusters

    end

  private

    def self.to_radians(degrees)
      degrees * (Math::PI / 180)
    end

    def self.distance_in_meters(p1, p2)
      dlon = to_radians(p2.lon) - to_radians(p1.lon)
      dlat = to_radians(p2.lat) - to_radians(p1.lat)
      a = (Math.sin(dlat/2))**2 + Math.cos(to_radians(p1.lat)) * Math.cos(to_radians(p2.lat)) * (Math.sin(dlon/2))**2
      c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a) )
      d = 6373 * c * 1000
    end

    def self.density_joinable(c1, c2, eps)
      c1.each do |p1|
        c2.each do |p2|
          if distance_in_meters(p1,p2) <= eps
            return true
          end
        end
      end unless c1.nil? || c2.nil?
      return false
    end

    def self.linear_neighborhood(points, point, eps)
      neighbours = [point]
      (point.idx-1).downto(0).each do |i|
        if distance_in_meters(point, points[i]) <= eps && points[i].processed == false
          neighbours.unshift(points[i])
        else
          break
        end
      end
      ((point.idx+1)..(points.size-1)).each do |i|
        if distance_in_meters(point, points[i]) <= eps && points[i].processed == false
          neighbours.push(points[i])
        else
          break
        end
      end

      return neighbours
    end
end