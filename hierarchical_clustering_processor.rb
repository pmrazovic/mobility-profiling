require "narray"

module HierarchicalClusteringProcessor
  Node = Struct.new(:points, :start_point, :end_point, :parent_node, :split_point, :children_nodes)
  
  public
    def self.run(r_plot, r_order, points)
      min_cluster_size = 3
      min_neighborhood_size = 2
      min_maxima_ratio = 0.0005
      
      nghsize = (min_maxima_ratio*r_order.size).to_i
      if nghsize < min_neighborhood_size
        nghsize = min_neighborhood_size
      end
      
      local_maxima_points = find_local_maxima(r_plot, r_order, nghsize)

      root_node = Node.new(r_order, 0, r_order.size-1, nil, nil, [])
      cluster_tree(root_node, nil, local_maxima_points, r_plot, r_order, min_cluster_size, 0)

      return extract_node_levels(root_node, points)
    end

  private
    def self.cluster_tree(node, parent_node, local_maxima_points, r_plot, r_order, min_cluster_size,level)
      if (local_maxima_points.size == 0)
         return
      end

      #take largest local maximum as possible separation between clusters
      s = local_maxima_points[0]
      node.split_point = s
      local_maxima_points.delete_at(0)

      #create two new nodes and add to list of nodes
      node_1 = Node.new(r_order[node.start_point..s-1], node.start_point, s-1, node, nil, [])
      node_2 = Node.new(r_order[s..node.end_point], s, node.end_point, node, nil, [])

      local_maxima_points_1 = [] # narray optimization
      local_maxima_points_2 = [] # narray optimization
      local_maxima_points.each do |p| # narray optimization
        local_maxima_points_1 << p if p < s
        local_maxima_points_2 << p if p > s
      end

      node_list = {node_1 => local_maxima_points_1, node_2 => local_maxima_points_2}

      # #set a lower threshold on how small a significant maxima can be
      # significant_min = 0.00003
      # if r_plot[s] < significant_min
      #   node.split_point = nil
      #   #if splitpoint is not significant, ignore this split and continue
      #   cluster_tree(node, parent_node, local_maxima_points, r_plot, r_order, min_cluster_size,level)
      #   return
      # end

      #only check a certain ratio of points in the child nodes formed to the left and right of the maxima
      check_ratio = 0.8
      check_value_1 = (check_ratio*node_1.points.size.round).to_i
      check_value_2 = (check_ratio*node_2.points.size.round).to_i
      check_value_2 = 1 if check_value_2 == 0
      
      avg_reach_value_1 = r_plot[(node_1.end_point - check_value_1)..node_1.end_point].mean
      avg_reach_value_2 = r_plot[node_2.start_point..(node_2.start_point + check_value_2)].mean

      #the maximum ratio we allow of average height of clusters on the right and left to the local maxima in question
      maxima_ratio = 0.75
      #if ratio above exceeds maximaRatio, find which of the clusters to the left and right to reject based on rejectionRatio
      rejection_ratio = 0.7

      if ((avg_reach_value_1 / r_plot[s].to_f) > maxima_ratio) || ((avg_reach_value_2 / r_plot[s].to_f) > maxima_ratio)
        if (avg_reach_value_1 / r_plot[s].to_f) < rejection_ratio
          #reject node 2
          node_list.delete(node_2)
        end
        if (avg_reach_value_2 / r_plot[s].to_f) < rejection_ratio
          #reject node 1
          node_list.delete(node_1)
        end
        if (avg_reach_value_1 / r_plot[s].to_f) >= rejection_ratio and (avg_reach_value_2 / r_plot[s].to_f) >= rejection_ratio
          node.split_point = nil
          #since splitpoint is not significant, ignore this split and continue (reject both child nodes)
          cluster_tree(node, parent_node, local_maxima_points, r_plot, r_order, min_cluster_size,level)
          return
        end
      end

      #remove clusters that are too small
      node_list.delete(node_1) if node_1.points.size < min_cluster_size
      node_list.delete(node_2) if node_2.points.size < min_cluster_size
      if node_list.size == 0
        #parent_node will be a leaf
        node.split_point = nil
        return
      end

      similarity_threshold = 0.4
      bypass_node = false
      unless parent_node.nil?
        sum_rp = r_plot[node.start_point..node.end_point].mean
        sum_parent = r_plot[parent_node.start_point..parent_node.end_point].mean
        if (sum_rp.to_f / sum_parent) > similarity_threshold
        # another expression of similarity 
        # if ((node.end_point-node.start_point).to_f / (parent_node.end_point-parent_node.start_point)) > similarity_threshold
          parent_node.children_nodes.delete(node)
          bypass_node = true
        end
      end
      
      node_list.each do |node_i,maxima_points_i|
        if bypass_node 
          parent_node.children_nodes << node_i
          cluster_tree(node_i, parent_node, maxima_points_i, r_plot, r_order, min_cluster_size,level+1)
        else
          node.children_nodes << node_i
          cluster_tree(node_i, node, maxima_points_i, r_plot, r_order, min_cluster_size,level+1)
        end
      end

    end

    def self.find_local_maxima(r_plot, r_order, ngh_size)
      local_maxima_points = {}
      (1..r_order.size-1).each do |i|
        if r_plot[i] > r_plot[i-1] && r_plot[i] >= r_plot[i+1] && is_local_maxima(i,r_plot,r_order,3)
          local_maxima_points[i] = r_plot[i]
        end
      end

      return local_maxima_points.keys.sort {|a, b| local_maxima_points[b] <=> local_maxima_points[a]}

    end

    def self.is_local_maxima(index, r_plot, r_order, ngh_size)
      (1..ngh_size).each do |i| 
        #process objects to the right of index
        if index + i < r_plot.size
          return false if (r_plot[index] < r_plot[index+i])
        end
      
        #process objects to the left of index
        if index - i >= 0
          return false if (r_plot[index] < r_plot[index-i])
        end
      end

      return true
    end

    def self.distance(p1,p2)
      Math.sqrt((p1[1]-p2[1])**2 + (p1[2]-p2[2])**2)
    end

    def self.to_radians(degrees)
      degrees * (Math::PI / 180)
    end

    def self.distance_in_meters(p1, p2)
      dlon = to_radians(p2[1]) - to_radians(p1[1])
      dlat = to_radians(p2[0]) - to_radians(p1[0])
      a = (Math.sin(dlat/2))**2 + Math.cos(to_radians(p1[0])) * Math.cos(to_radians(p2[0])) * (Math.sin(dlon/2))**2
      c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a) )
      d = 6373 * c * 1000
    end

    def self.extract_node_levels(root_node, r_points)
      framework = Array.new
      queue = [ {:points => r_points[true,root_node.points].to_a,
                 :parent_node => nil,
                 :children_nodes => root_node.children_nodes,
                 :level_idx => 0} ]

      while queue.size > 0
        current = queue.shift
        framework[current[:level_idx]] ||= []
        
        # removing outliers at the beginning and end of cluster
        if distance(current[:points][-2],current[:points][-3])/distance(current[:points][-1],current[:points][-2]).to_f < 0.3
          current[:points].delete_at(-1)
        end
        if distance(current[:points][1],current[:points][2])/distance(current[:points][0],current[:points][1]).to_f < 0.3
          current[:points].delete_at(0)
        end

        current_children_nodes = []
        current[:children_nodes].each do |cn|
          current_children_nodes << { :points => r_points[true,cn.points].to_a,
                                      :parent_node => current,
                                      :children_nodes => cn.children_nodes,
                                      :level_idx => current[:level_idx] + 1}
        end

        current[:children_nodes] = current_children_nodes
        current[:cluster_idx] = framework[current[:level_idx]].size
        framework[current[:level_idx]] << current

        queue += current[:children_nodes]
      end

      return framework
    end

end