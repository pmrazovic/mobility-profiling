# HOSVD for 3rd-order tensor (e.g. user x location x time)

require "narray"
require 'numru/lapack'

def kronecker_product(a,b)
  result = NArray.float(a.shape[0]*b.shape[0],a.shape[1]*b.shape[1])
  puts result.inspect
  (0..a.shape[0]-1).each do |idx0|
    (0..a.shape[1]-1).each do |idx1|
      puts idx0*b.shape[0]
      puts idx0*b.shape[0]+b.shape[0]
      puts idx1*b.shape[1]
      puts idx1*b.shape[1]+b.shape[1]
      result[idx0*b.shape[0]..(idx0*b.shape[0]+b.shape[0]-1),idx1*b.shape[1]..(idx1*b.shape[1]+b.shape[1]-1)] = a[idx0,idx1]*b
    end
  end
  return result
end

def unfold(tensor,axis)
  # NArray follows FORTRAN index ordering (I_2 (axis_2) x I_1 (axis_1) x I_3 (axis_3))

  dim = tensor.shape
  elem_count = dim.inject(:*)

  if axis == 0
    a_u = NArray.float(dim[0],dim[1]*dim[2])
    count = 0
    (0..dim[1]-1).each do |idx1|
      (0..dim[2]-1).each do |idx2|
        a_u[true,count] = tensor[true,idx1,idx2]
        count += 1
      end      
    end
  elsif axis == 1
    a_u = NArray.float(dim[1],dim[0]*dim[2])
    count = 0
    (0..dim[0]-1).each do |idx0|
      (0..dim[2]-1).each do |idx2|
        a_u[true,count] = tensor[idx0,true,idx2]
        count += 1
      end      
    end
  elsif axis == 2
    a_u = NArray.float(dim[2],dim[0]*dim[1])
    count = 0
    (0..dim[0]-1).each do |idx0|
      (0..dim[1]-1).each do |idx1|
        a_u[true,count] = tensor[idx0,idx1,true]
        count += 1
      end      
    end
  end

  return a_u
end

def fold(matrix,axis)
  # NArray follows FORTRAN index ordering (I_2 (axis_2) x I_1 (axis_1) x I_3 (axis_3))
end

def hosvd(tensor)
  mode_matrices = []
  n_mode_singular_values = []
  (0..2).each do |axis|
    s, u, vt, work, info, a = NumRu::Lapack.dgesvd( 'A', 'A', unfold(tensor,axis))
    mode_matrices << u
    n_mode_singular_values << s
  end
  
  # core tensor unfolded along axis 0
  s_u = mode_matrices[0]*unfold(tensor,0)*kronecker_product(mode_matrices[1]*mode_matrices[2])
end



t = NArray[ [ [ 1.0, 1.0, 2.0 ], 
              [ 2.0, 2.0, 4.0 ] ], 
            [ [ 1.0, -1.0, 0.0 ], 
              [ 2.0, -2.0, 0.0 ] ], 
            [ [ 0.0, 2.0, 2.0 ], 
              [ 0.0, 4.0, 4.0 ] ] ]
              
# hosvd(t)

a = NArray[[1,0],[0,2]]
b = NArray[[1,2,1],[1,0,1],[2,0,1]]

puts a.inspect
puts b.inspect
puts kronecker_product(a,b).inspect