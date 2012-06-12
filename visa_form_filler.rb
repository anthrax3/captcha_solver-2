# encoding: windows-1251

require 'rubygems'
require 'watir'
#require 'watir-webdriver'

#$kraj = "6"
#$placowka = "95"

$kraj = "43"
$placowka = "148"


$file_name = Dir.pwd + "/captcha.png"

browser = Watir::IE.new
browser.goto 'https://secure.e-konsulat.gov.pl/'

browser.select_list( :id => 'ctl00_ddlWersjeJezykowe' ).select '17'
sleep( 2 )

Watir::Wait.while do
	browser.select_list( :id => 'ctl00_tresc_cbListaKrajow' ).select $kraj
	sleep(0.5)
	browser.div( :id, "ctl00_tresc_upPlacowka" ).select_lists.size == 0 || browser.div( :id, "ctl00_tresc_upPlacowka" ).select_list( :id, 'ctl00_tresc_cbListaPlacowek' ).options.size == 0
end 

browser.div( :id, "ctl00_tresc_upPlacowka" ).select_list( :id, 'ctl00_tresc_cbListaPlacowek' ).select $placowka
sleep(1)
browser.goto 'https://secure.e-konsulat.gov.pl/Uslugi/RejestracjaTerminu.aspx?IDUSLUGI=8&idpl=0'
captcha_src = browser.image( :id, 'ctl00_ContentPlaceHolder1_KomponentObrazkowy_CaptchaImageID').src

exit

i = 0
while ( i < 1 )
	File.delete( "captcha.png" ) if File.exist?( "captcha.png" )
	browser.image( :id, 'ctl00_ContentPlaceHolder1_KomponentObrazkowy_CaptchaImageID').save( $file_name )
	puts system('ruby solve_captcha.rb')
#	browser.button( :id, 'ctl00_ContentPlaceHolder1_btnDalej' ).click
	sleep( 3 )
	i += 1
end
