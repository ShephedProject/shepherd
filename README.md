Shepherd Guide Grabber
======================

Shepherd delivers reliable, high-quality Australian TV guide data (EPG).

### Background
The Shepherd project began in 2007 when Australians with Home Theatre PCs lacked a good method of obtaining an EPG. The free-to-air stations fought against the free availability of such data, apparently fearing that Home Theatre PCs / PVRs would allow people to skip ads. Instead, they filed lawsuits, sent cease & desist letters, and obfuscated their online guides [Source](http://www.smh.com.au/news/biztech/legal-battle-over-electronic-guides/2006/06/19/1150569266669.html?page=fullpage).

Australians had two options:
1. Download an EPG from [OzTivo](http://www.oztivo.net/twiki/bin/view/TVGuide/WebHome), which was community produced by users manually describing shows
2. Use a script to access data in an online TV guide such as [Yahoo!](http://au.tv.yahoo.com/tv-guide/)

Each method had drawbacks. The community-generated EPG could be unreliable in non-metro areas, tended to only include the most basic of show details, and was somewhat error-prone. The scripts would stop working each time the associated online guide changed format, which happened frequently as the sites tried to deny them access.

Shepherd solved this problem by:
1. Employing a flock of online guide grabbers, and switching between them on the fly as necessary to cover failures
2. Auto-updating, thus eliminating the need for users to manually intervene to fix problems

In 2013, Australians have more options. [IceTV](http://www.icetv.com.au) won its legal battle and sells an EPG online; many hardware HTPC/PVR devices exist with inbuilt EPG; and the TV stations themselves broadcast an EPG via EIT, which although still somewhat error-ridden is improving considerably. Nevertheless, Shepherd remains a free, robust method of obtaining high-quality guide data, particularly for MythTV.

### Description / Features
Shepherd knows the capabilities of each grabber and can make intelligent decisions about how and when to deploy them to maximize data quality and coverage. It analyses the output from each grabber to determine whether any further grabbers are required to obtain a full dataset of required channels, and employs postprocessors to further supplement the data with information from sources such as [IMDB](imdb_augment_data) and Metacritic.

When switching between data sources, Shepherd is able to keep show names consistent. For example, if you're used to recording a programme called _"House"_ but a different data source names it _"House, M.D."_, Shepherd is able to identify the second name as a variation of the first, and automatically substitute the original in order to match any recording rules you have established.

Shepherd is particularly useful for MythTV users, as it can feed guide data automatically to MythTV with minimal user configuration. It can even install MythTV [channel icons](wiki:channel_icons).

Shepherd is future-proof, requiring no manual intervention once installed. It will automatically update itself with fixes, enhancements, and additional grabbers and postprocessors as they become available.

### Download & Installation
See the [Installation](https://github.com/ShephedProject/shepherd/wiki/Installation) page.

### How does it work?
 * The [FAQ](https://github.com/ShephedProject/shepherd/wiki/FAQ) wiki page contains some questions and answers.
 * The [shepherd_logic](https://github.com/ShephedProject/shepherd/wiki/shepherd_logic) wiki page describes how shepherd works. The default policies used by shepherd are documented on the [Policies](Policies) wiki page.
 * The [Security](https://github.com/ShephedProject/shepherd/wiki/Security) page discusses security issues associated with Shepherd.


### More Information
Wiki content was migrated from original whuffy host to the [Github Wiki](https://github.com/ShephedProject/shepherd/wiki/)

### Contributing
Please see [CONTRIBUTING](CONTRIBUTING.md)