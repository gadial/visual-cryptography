require 'rubygems'
require 'RMagick'
require 'optparse'
require 'DoubleArray'

class Integer
	def to_bin(minimum_length=0)
		#outputs array of 1 and 0 according to the binary representation
		temp=self.to_s(2).split("").collect{|x| x.to_i}
		while temp.length<minimum_length
			temp.unshift(0)
		end
		return temp
	end
end


def preprocess_images(images)
	#transforms to monochrome. Resizes to the smallest size if needed, does another 0.5 shrink
	min_x=images.to_a.collect{|image| image.columns}.min
	min_y=images.to_a.collect{|image| image.rows}.min
	images.collect!{|image| image.resize(min_x,min_y)}
	images.collect!{|image| image.resize(0.5)}
	images.collect!{|image| image.quantize(2,Magick::GRAYColorspace)} #monochrome

	return images
end

def name_to_number(name)
	case name
		when "white": return 1
		when "black": return 0
	end
end

def number_to_name(number)
	case number
		when 1: return "white"
		when 0: return "black"
	end
end

def subpixel_square(code)
	code.to_bin(4).collect{|x| Magick::Pixel.from_color(number_to_name(x))}	
end

def image_from_share(share)
	image=Magick::Image.new(share.size_x*2, share.size_y*2)
	share.each_index{|i,j| image.store_pixels(i*2,j*2,2,2,share[i,j])}
	return image
end

def image_to_array(image, copy_pixels=false)
	array=DoubleArray.new(image.columns,image.rows)
	image.each_pixel{|pixel,i,j| array[i,j]=name_to_number(pixel.to_color)} if copy_pixels
	return array
end

def simple_crypto(filename)
	image = Magick::ImageList.new(filename)
 	preprocess_images(image)

	source = image_to_array(image,true)
	share1 = image_to_array(image)
	share2 = image_to_array(image)

	share1.each_index{|i,j| share1[i,j]=rand(2)}
	share2.each_index{|i,j| share2[i,j]=(source[i,j]==1)?(share1[i,j]):(1-share1[i,j])}

	black_left_half = subpixel_square(10)
	black_right_half = subpixel_square(5)

	share1_image=image_from_share(share1.collect{|x| (x==1)?(black_left_half):(black_right_half)})
	share2_image=image_from_share(share2.collect{|x| (x==1)?(black_left_half):(black_right_half)})
	
	share1_image.write("s1.png")
	share2_image.write("s2.png")
end

def spin(array, times=1)
	#spins a 2x2 array clockwise
	return array if times == 0
	return [array[2],array[0],array[3],array[1]] if times == 1
	return spin(spin(array,times-1)) if times > 1
end

def multiple_image_crypto(source1_filename, source2_filename, target_filename)
	translation_table={ #[first source color, second source color, target color] => [share1 code, share2 code]
		[0,0,0] => [8,1],
		[1,0,0] => [10,1],
		[0,1,0] => [8,5],
		[1,1,0] => [10,5],
		[0,0,1] => [8,8],
		[1,0,1] => [10,8],
		[0,1,1] => [1,5],
		[1,1,1] => [10,3]
	}	

	images = Magick::ImageList.new(source1_filename,source2_filename,target_filename)
	preprocess_images(images)
	
	source1 = image_to_array(images[0],true)
	source2 = image_to_array(images[1],true)
	target 	= image_to_array(images[2],true)
	share1	= image_to_array(images)
	share2	= image_to_array(images)

	target.each_index do |i,j|
		to_spin=rand(4)
		shares=translation_table[[source1[i,j],source2[i,j],target[i,j]]].collect{|x| spin(subpixel_square(x),to_spin)}
		share1[i,j]=shares[0]
		share2[i,j]=shares[1]
	end
	share1_image=image_from_share(share1)
	share2_image=image_from_share(share2)

	share1_image.write("s1.png")
	share2_image.write("s2.png")
end

# image = Magick::ImageList.new("t.gif")
# # image.each_pixel{|x,i,j| puts x}
# p=Magick::Pixel.new(0,3,5,1)
# puts p.inspect
# #image.display
# # image=list[0]
# # puts image.inspect
# # image.each_pixel{|x,i,j| puts x.inspect}

# pic = Magick::ImageList.new("h.gif")
# pic = pic.resize(0.5).quantize(2,Magick::GRAYColorspace)
# pic.write('t.gif')

# def parse_options
#   options = {}
# 
#   opts = OptionParser.new
# #   opts.on("-q", "--quiet") do
# #     options[:quiet] = true
# #   end
#   opts.on("-s", "--trees") do
# 	options[:type] = true
#   end
#   opts.on("-n N", "(mandatory)", Integer) do |n|
#     options[:n] = n
#   end
#   opts.on("-d D", "(mandatory)", Integer) do |d|
#     options[:d] = d
#   end
#   opts.on("-v", "--verbose") do
# 	options[:verbose]=true
#   end
# 
#   begin
#     opts.parse!
#     raise unless options[:n] and options[:d]
#   rescue
#     puts opts
#     exit 1
#   end
# 
#   options
# end
# 
# if $0 == __FILE__
#   options = parse_options
#   test = RedelmeierAlgorithm.new(options)
#   test.run.print_results unless options[:quiet]
# end
# multiple_image_crypto("homer.gif","marge.png", "bart.png")
simple_crypto("homer.gif")

