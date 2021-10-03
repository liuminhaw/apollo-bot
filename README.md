# apollo-bot
Automatic apply for re-checkin on apollo hr system.

## Version

### v0.1.0
- Re-checkin process automation
- `--config` option to specify config file to read
- `--include` option to manual include date such as workday on weekend
- `--exclude` option to manual exclude date such as national holidays
- `--version` option shows program version information

## Usage
```
apollo-recheckin.sh [--help] [--version] [--config CONFIG] [--exclude "dd dd ..."] [--include "dd dd ..."] startDate endDate
	--help							Display this help message and exit
	--config CONFIG	 				Specify configuration file to read 
									(Default file: config)
	--exclude "dd dd ..."			Excluding dates for applying re-checkin
	--include "dd dd ..."			Including dates for applying re-checkin
	--version						Show script version
	startDate						Start date for applying recheckin, format: YYYY-mm-dd
	endDate							End date for applying recheckin, format: YYYY-mm-dd
```
Re-checkin will be applied if weekday is matched, weekend will be skipped.  
Use `--include` and `--exclude` options to get specific date to be applied or skipped.

`--include` option has higher priority then `--exclude` option if same date was given to both options, which should be avoided.

## Exit code
1 - Usage error  
2 - Function usage error  
3 - Missing config