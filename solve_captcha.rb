
require 'rubygems'
require 'RMagick'
require 'thread'
include Magick

$log = false
$time_log = false
$deadlock_log = true

$max_color = 2 ** (Magick::QuantumDepth) - 1

$start_time = Time.now

class Time
	def pretty_str()
		return "#{strftime("%Y_%m_%d_%H_%M_%S_")}#{usec}"
	end
end

def black_pixel( img, i, u, level = 0 )
	p = img.get_pixels( i, u, 1, 1 )[0]
    color = level * $max_color
	return (p.red <= color && p.green <= color && p.blue <= color ) 
end


def channels_correction( img, level = 0, pixel = Pixel.new( $max_color, $max_color, $max_color ), finish = $max_color )
	new_img = img.copy
	(0..img.columns - 1).each do |i| 
		(0..img.rows - 1).each do |u|
			if ( black_pixel( img, i, u, level ) )
			else
				new_img.store_pixels( i, u, 1, 1, [ Pixel.new( finish, finish, finish ) ] )
			end
		end
	end
	new_img
end 

def if_black_do_block_and_queue_it( img, i,  u, q, block, level = 0, params = [] )
	if ( i >= 0 && u >=0 && i < img.columns && u < img.rows && black_pixel( img, i, u, level ) )
		block.call( img, i, u, params )
		q << [i, u]
	end
end

def delete_black_island( img, i, u, level )
	q = Queue.new
	proc = Proc.new { |img, i, u| img.store_pixels( i, u, 1, 1, [ Pixel.new( $max_color, $max_color, $max_color )] ) }

	if_black_do_block_and_queue_it( img, i, u, q, proc, level )

	while ( q.size > 0 )
		c = q.pop

		if_black_do_block_and_queue_it( img, c[0] - 1, c[1], q, proc, level )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1], q, proc, level )
		if_black_do_block_and_queue_it( img, c[0], c[1] - 1, q, proc, level )
		if_black_do_block_and_queue_it( img, c[0], c[1] + 1, q, proc, level )
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1] - 1, q, proc, level )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1] - 1, q, proc, level )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1] + 1, q, proc, level )
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1] + 1, q, proc, level )
	end
end

def delete_border_touch( img, level = 150 )
	(0..img.columns - 1).each do |i| 
		delete_black_island( img, i, 0, level ) if black_pixel( img, i, 0, level )
	end
	(0..img.columns - 1).each do |i| 
		delete_black_island( img, i, img.rows-1, level ) if black_pixel( img, i, img.rows-1, level )
	end
	(0..img.rows - 1).each do |u| 
		delete_black_island( img, 0, u, level ) if black_pixel( img, 0, u, level )
	end
	(0..img.rows - 1).each do |u| 
		delete_black_island( img, img.columns - 1, u, level ) if black_pixel( img, img.columns - 1, u, level )
	end
	img
end

def find_black_pixel( img, start_line = 0 )
	(start_line..img.columns - 1).each do |i| 
		(0..img.rows - 1).each do |u|
			if ( black_pixel( img, i, u ) )
				return [i, u]
			end
		end
	end
	return nil
end

def separate_symbol( img )
	i, u = find_black_pixel( img, start_line = 0 )
	return nil if i == nil	
	q = Queue.new
	q << [i, u]
	l_i = img.copy
	l_i.erase!
	params = [ l_i, img.columns, img.rows, 0, 0 ]
	while q.size > 0 do
		c = q.pop
		proc = Proc.new do |img, i, u, params| 
			params[0].store_pixels( i, u, 1, 1, [ Pixel.new(0, 0, 0)] )
			img.store_pixels( i, u, 1, 1, [ Pixel.new(255, 255, 255)] )
			params[1] = i if i < params[1]
			params[2] = u if u < params[2]
			params[3] = i if i > params[3]
			params[4] = u if u > params[4]
		end
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1], q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1], q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0], c[1] - 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0], c[1] + 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1] - 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1] - 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1] + 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1] + 1, q, proc, 0, params )
	end
	l_i.excerpt!( params[1], params[2], params[3] - params[1] + 1, params[4] - params[2] + 1 )
	return l_i
end

def separate_letters( img )
	answer = []
	new_img = img.copy
	i = 0 
	while ( symbol = separate_symbol( new_img ) )
		i += 1
		break if i > 4
		break if symbol.columns < 0 || symbol.rows < 0
		answer << symbol
	end
	answer
end

class SymbolCompareKoefficient
	attr_accessor :ss, :koefficient
	def initialize( s, k )
		@ss = s
		@koefficient = k
	end
	def to_s()
		"[#{ @ss.to_s }:#{ "%04f" % @koefficient }]\t"
	end
end


def create_equal_map( base, img )
	base.each do |symbol, files|
		i = 0
		amount = 0
		files.each { |file_name| 
			k = image_compare( img, file_name )
			i += k
			amount += 1
		}
		if ( amount > 0 )
			img_to_letter << SymbolCompareKoefficient.new( symbol, (1.0 * i / amount) )

			if ( (1.0 * i / amount) > max_i )
				max_i = 1.0 * i / amount
				max_symbol = symbol
			end
		end
	end
	[ max_symbol, img_to_letter ]
end


def image_compare( image, file_name )
	expected = Magick::Image::read( file_name ).first
    return 0 if !expected
	k = 0
	min_i = ( image.columns < expected.columns )? image.columns : expected.columns;
	min_u = ( image.rows < expected.rows )? image.rows : expected.rows;
    return 0 if (min_i == 0 || min_u == 0)
	(0..min_i - 1).each do |i|
		(0..min_u - 1).each do |u|
			p1 = image.get_pixels( i, u, 1, 1)[0]
			p2 = expected.get_pixels( i, u, 1, 1)[0]
			if ( p1.red == p2.red && p1.green == p2.green && p1.blue == p2.blue )
				k += 1
			end
		end
	end
	k
end


class LetterGroup
	def initialize( group_name )
		@group_name = group_name
		@letter_images = []
	end
	def add_file( file_path )
		@letter_images << file_path
	end
	def koefficient( img )
		k = 1.0
		@letter_images.each { |file_path|
			k += image_compare( img, file_path )
		}
		if @letter_images.size > 0
			return k / @letter_images.size 
		else
			return 0.0
		end
	end
	def to_s
		ans = @letter_images.size.to_s
	end
end

class Letter
	def initialize( letter )
		@letter = letter
		@letter_groups = {}
	end
	def add_group( group_name )
		@letter_groups[ group_name ] = LetterGroup.new( group_name )
	end
	def add_file( group_name, file_path )
		@letter_groups[ group_name ].add_file( file_path )
	end
	def koefficient( img )
		max_k = 0
		@letter_groups.each { |kn, lg| 
			k = lg.koefficient( img )
			max_k = k if ( k > max_k )
		}
		max_k
	end
	def to_s
		ans = " * Letter: " + @letter + " "
		@letter_groups.each { |k, v| ans += "'" + k + "' " + v.to_s }
		ans
	end
end

class ImageBase
	def initialize()
		@letters = {}
	end
	def add_key( letter )
		@letters[ letter ] = Letter.new( letter )
	end
	def add_letter_group( letter, group_name )
		@letters[ letter ].add_group( group_name )
	end
	def add_file( letter, group_name, file_path )
		@letters[ letter ].add_file( group_name, file_path )
	end
	def to_s
		ans = ""
		@letters.each { |k, v| puts v }
		ans
	end
	def create_letter_array( img )
		img_to_letter = []
		@letters.each { |k, v| 
            img_to_letter << SymbolCompareKoefficient.new( k, v.koefficient( img ) ) 
        }
		img_to_letter.sort!{ |i, u| u.koefficient <=> i.koefficient }
		img_to_letter
	end
end

def create_base()
	base = ImageBase.new
	Dir.foreach( "base" ) do |item|
		next if item == "." || item == ".."
		if (item.size > 1 && item[0, 1] == "_") 
			letter = item[1, 1]
		else
			letter = item
		end
		base.add_key( letter )
		base.add_letter_group( letter, "" )

		Dir.foreach( "base/" + item ) do |subitem|
			next if subitem == "." || subitem == ".."
			folder_path = "base/" + item + "/" + subitem
			if File.directory?( folder_path )
				base.add_letter_group( letter, subitem )
				Dir.foreach( folder_path ) do |subsubitem|
					next if subsubitem == "." || subsubitem == ".."
					file_path = folder_path + "/" + subsubitem
					base.add_file( letter, subitem, file_path )
				end
			else
				base.add_file( letter, "", folder_path )
			end			
		end
	end
	return base
end

def black_correction( img, correction_coefficient = 0.4183, finish = $max_color  )
	new_img = img.copy
	(0..img.columns - 1).each do |i| 
		(0..img.rows - 1).each do |u|
			p = img.get_pixels( i, u, 1, 1 )[0]
			color = p.red + p.green + p.blue
			if ( color >= (3 * $max_color ) * correction_coefficient )
				new_img.store_pixels( i, u, 1, 1, [ Pixel.new( finish, finish, finish ) ] )
			end
		end
	end
	new_img
end 

def delete_island( img, i, u )
    
	is = 0
	q = Queue.new
	proc = Proc.new do | img, i, u, params | 
		img.store_pixels( i, u, 1, 1, [ Pixel.new( $max_color, $max_color, $max_color ) ] )
	end
	params = []

	if_black_do_block_and_queue_it( img, i, u, q, proc, 0, params )

	while ( q.size > 0 )
		c = q.pop
		is += 1
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1], q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1], q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0], c[1] - 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0], c[1] + 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1] - 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1] - 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] + 1, c[1] + 1, q, proc, 0, params )
		if_black_do_block_and_queue_it( img, c[0] - 1, c[1] + 1, q, proc, 0, params )
	end
    return is;

end
    
def delete_small_island( img, size = 1 )
	img_copy = img.copy
	(0..img_copy.columns - 1).each do |i| 
		(0..img_copy.rows - 1).each do |u|
			if ( black_pixel( img_copy, i, u ) )
				island_size = delete_island( img_copy, i, u)
				if (island_size <= size)
					delete_island( img, i, u )
				end
			end
		end
	end
	img
end

def all_non_white_black( img )
	new_img = img.copy
	(0..img.columns - 1).each do |i| 
		(0..img.rows - 1).each do |u|
			p = img.get_pixels( i, u, 1, 1 )[0]
			color = p.red + p.green + p.blue
			if ( color != $max_color * 3 )
				new_img.store_pixels( i, u, 1, 1, [ Pixel.new(0, 0, 0) ] )
			end
		end
	end
	new_img
end 
    
def generate_img_to_letter( file_name = "captcha.png" )
    img = Image.read( file_name ).first
    img.crop!(10, 3, 130, 45)
    img = channels_correction( img, 0.70588, Pixel.new( 0, 0, 0 ) )
    img.write( "_debug_l_1.png" ) if $log
    img = black_correction( img, 0.4183 )
    img.write( "_debug_l_2.png" ) if $log
    img = delete_border_touch( img, 0.588 )
    img.write( "_debug_l_3.png" ) if $log
    img = all_non_white_black( img )
    img.write( "_debug_l_4.png" ) if $log
    img = delete_border_touch( img, 0.196 )
    img.write( "_debug_l_5.png" ) if $log
    img = delete_small_island( img, 15 )
    img.write( "result.png") if $log
    
    imgs = separate_letters( img )
    
    run_str = Time.now.pretty_str
    
    if ( $log )
        imgs.each_index do |i| 
            imgs[ i ].write( "_debug_l_#{run_str}_#{i}.png" )
        end
    end
    
    base = create_base()
    
    img_to_letter = []
    
    imgs.each_index do |img_index|
        img_to_letter[ img_index ] = base.create_letter_array( imgs[ img_index ] )
        puts "#{img_index} processed" if $log
    end
    [imgs,img_to_letter]
end

def print_coefficients( file_name = "captcha.png", size = 5 )

    imgs, img_to_letter = generate_img_to_letter( file_name )

    imgs.each_index do |img_index|
        max_st = size
        amount = ( max_st < img_to_letter[ img_index ].size ) ? max_st : img_to_letter[ img_index ].size - 1
        (0..amount).each { |i| print img_to_letter[ img_index ][ i ] }
        print "\n"
    end
end

def solve_captcha( file_name = "captcha.png" )
    imgs, img_to_letter = generate_img_to_letter( file_name )
    str = ""
    imgs.each_index do |img_index|
        str += img_to_letter[ img_index ][ 0 ].ss
    end
    str
end

if ( __FILE__ == $0 )
    puts solve_captcha
    #    print_coefficients()
end

$end_time = Time.now

puts $end_time - $start_time if $time_log

