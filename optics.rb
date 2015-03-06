require "narray"

module OPTICS

  public # -------------------------------

    def self.run(x,k)
      n,m = x.shape

      core_distances = NArray.float(m)
      reachability_distances = NArray.float(m).fill!(1E10)

      (0..m-1).each do |i|
        d = euclid_distance(x[true,i],x)
        d.sort!
        core_distances[i] = d[k]
      end

      order = []
      seeds = NArray.int(m).indgen!(0,1)
      ind = 0
      while seeds.size != 1 do
        ob = seeds[ind]
        seed_ind = seeds.ne(ob).where
        seeds = seeds[seed_ind]

        order << ob
        temp_x = NArray.float(seeds.size).fill!(core_distances[ob])
        temp_d = euclid_distance(x[true,ob],x[true,seeds])

        temp = NArray[temp_x,temp_d].transpose(1,0) # column stack
        mm = temp.max(0)
        ii = reachability_distances[seeds].gt(mm).where
        reachability_distances[seeds[ii]] = mm[ii]
        ind = reachability_distances[seeds].eq(reachability_distances[seeds].min).where[0] # argmin
      end

      order << seeds[0]
      reachability_distances[0] = 0 #we set this point to 0 as it does not get overwritten
      return reachability_distances, core_distances, order

    end

  private # -------------------------------

    def self.euclid_distance(i,x)
      y = NArray.float(x.shape[0],x.shape[1]).fill!(1)
      y *= i
      d = (x-y)**2
      return NMath.sqrt(d.sum(0))
    end

end