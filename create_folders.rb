Dir.mkdir( "base" ) if (!File.exists?( "base" ))
('a'..'z').each { |i| 
	folder = "base/" + i
	Dir.mkdir( folder ) if (!File.exists?( folder )) 
}
('A'..'Z').each { |i| 
	folder = "base/_" + i
	Dir.mkdir( folder ) if (!File.exists?( folder )) 
}
('0'..'9').each { |i| 
	folder = "base/" + i
	Dir.mkdir( folder ) if (!File.exists?( folder )) 
}
['!', '@', '#', '$', '%', '^', '&', '=', '-', '+'].each { |i| 
	folder = "base/" + i
	Dir.mkdir( folder ) if (!File.exists?( folder )) 
}
#Dir.mkdir( "new_images" ) if (!File.exists?( "new_images" ))
#Dir.mkdir( "letters" ) if (!File.exists?( "letters" ))
