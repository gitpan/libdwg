my $rh_preferences = { 
	page_header => undef,
	page_footer => <<__endquote,
<P><EM>This site is an example of what can be done with the Dynamic 
Website Generator collection of Perl 5 modules, copyright (c) 
1999-2000, Darren R. Duncan.</EM></P>
__endquote
	page_css_code => [
		'BODY {background-color: white; background-image: none}'
	],
	vrp_handlers => {
		external => {
			wpm_module => 'CGI::WPM::Redirect',
			wpm_prefs => {},
		},
		frontdoor => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'frontdoor.html' },
		},
		resume => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'resume.html' },
		},
		mysites => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'mysites.html' },
		},
		myperl => {
			wpm_module => 'CGI::WPM::MultiPage',
			wpm_subdir => 'myperl',
			wpm_prefs => 'myperl_prefs.pl',
		},
		mailme => {
			wpm_module => 'CGI::WPM::MailForm',
			wpm_prefs => {},
		},
		guestbook => {
			wpm_module => 'CGI::WPM::GuestBook',
			wpm_prefs => {
				fn_field_def => 'guestbook_questions.txt',
				fn_messages => 'guestbook_messages.txt',
			},
		},
		links => {
			wpm_module => 'CGI::WPM::Static',
			wpm_prefs => { filename => 'links.html' },
		},
	},
	def_handler => 'frontdoor',
	menu_items => [
		{
			menu_name => 'Front Door',
			menu_path => '',
			is_active => 1,
		}, 1, {
			menu_name => 'Resume',
			menu_path => 'resume',
			is_active => 1,
		}, {
			menu_name => 'Web Sites I Made',
			menu_path => 'mysites',
			is_active => 1,
		}, {
			menu_name => 'Perl Libraries I Made',
			menu_path => 'myperl',
			is_active => 1,
		}, 1, {
			menu_name => 'E-mail Me',
			menu_path => 'mailme',
			is_active => 1,
		}, {
			menu_name => 'Read Guest Book',
			menu_path => 'guestbook',
			is_active => 1,
		}, {
			menu_name => 'Sign Guest Book',
			menu_path => 'guestbook/sign',
			is_active => 1,
		}, 1, {
			menu_name => 'Other Links',
			menu_path => 'links',
			is_active => 1,
		},
	],
	menu_cols => 4,
#	menu_colwid => 100,
	menu_showdiv => 0,
#	menu_bgcolor => '#ddeeff',
	page_showdiv => 1,
};
