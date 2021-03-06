###############################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################
# Backtest Functions
# Copyright (C) 2011  Michael Kapler
#
# For more information please visit my blog at www.SystematicInvestor.wordpress.com
# or drop me a line at TheSystematicInvestor at gmail
###############################################################################


###############################################################################
# Align dates, faster version of merge function
#' @export 
###############################################################################
bt.merge <- function
(
	b,				# enviroment with symbols time series
	align = c('keep.all', 'remove.na'),	# alignment type
	dates = NULL	# subset of dates
) 
{
	align = align[1]
	symbolnames = b$symbolnames
	nsymbols = len(symbolnames) 
	
	# count all series
	ncount = sapply(symbolnames, function(i) nrow(b[[i]]))
		all.dates = double(sum(ncount))		
		
	# put all dates into one large vector
	itemp = 1
	for( i in 1:nsymbols ) {
		all.dates[itemp : (itemp + ncount[i] -1)] = attr(b[[ symbolnames[i] ]], 'index')
		itemp = itemp + ncount[i]
	}
		
	# find unique
	temp = sort(all.dates)
	unique.dates = c(temp[1], temp[-1][diff(temp)!=0])
	
	# trim if date is supplied	
	if(!is.null(dates)) { 
		class(unique.dates) = c('POSIXct', 'POSIXt')	
		temp = make.xts(integer(len(unique.dates)), unique.dates) 		
		unique.dates = attr(temp[dates], 'index')
	}
		
	# date map
	date.map = matrix(NA, nr = len(unique.dates), nsymbols)
	itemp = 1
	for( i in 1:nsymbols ) {
		index = match(all.dates[itemp : (itemp + ncount[i] -1)], unique.dates)
		sub.index = which(!is.na(index))
		date.map[ index[sub.index], i] = sub.index
		itemp = itemp + ncount[i]
	}
	
	# trim logic
	index = c()
	if( align == 'remove.na' ) { 
		index = which(count(date.map, side=1) < nsymbols )
	} 
	# keep all
#	else {
#		index = which(count(date.map, side=1) < max(1, 0.1 * nsymbols) )
#	}
	
	if(len(index) > 0) { 
		date.map = date.map[-index,, drop = FALSE]
		unique.dates = unique.dates[-index] 
	}
	
	class(unique.dates) = c('POSIXct', 'POSIXt')	
	return( list(all.dates = unique.dates, date.map = date.map))
}


###############################################################################
# Prepare backtest data
#' @export 
###############################################################################
bt.prep <- function
(
	b,				# enviroment with symbols time series
	align = c('keep.all', 'remove.na'),	# alignment type
	dates = NULL,	# subset of dates
	fill.gaps = F	# fill gaps introduced by merging
) 
{    
	# setup
	if( !exists('symbolnames', b, inherits = F) ) b$symbolnames = ls(b)
	symbolnames = b$symbolnames
	nsymbols = len(symbolnames) 
	
	if( nsymbols > 1 ) {
		# merge
		out = bt.merge(b, align, dates)
		
		for( i in 1:nsymbols ) {
			b[[ symbolnames[i] ]] = 
				make.xts( coredata( b[[ symbolnames[i] ]] )[ out$date.map[,i],, drop = FALSE], out$all.dates)
		
			# fill gaps logic
			map.col = find.names('Close,Volume,Open,High,Low,Adjusted', b[[ symbolnames[i] ]])
			if(fill.gaps & !is.na(map.col$Close)) {	
				close = coredata(b[[ symbolnames[i] ]][,map.col$Close])
					n = len(close)
					last.n = max(which(!is.na(close)))
				close = ifna.prev(close)
				if(last.n + 5 < n) close[last.n : n] = NA
				b[[ symbolnames[i] ]][, map.col$Close] = close
					index = !is.na(close)	

				if(!is.na(map.col$Volume)) {
					index1 = is.na(b[[ symbolnames[i] ]][, map.col$Volume]) & index
					b[[ symbolnames[i] ]][index1, map.col$Volume] = 0
				}
				
				#for(j in colnames(b[[ symbolnames[i] ]])) {
				for(field in spl('Open,High,Low,Adjusted')) {
				j = map.col[[field]]
				if(!is.null(j)) {
					index1 = is.na(b[[ symbolnames[i] ]][,j]) & index
					b[[ symbolnames[i] ]][index1, j] = close[index1]
				}}						
			}
		}	
	} else {
		if(!is.null(dates)) b[[ symbolnames[1] ]] = b[[ symbolnames[1] ]][dates,]	
		out = list(all.dates = index.xts(b[[ symbolnames[1] ]]) )
	}

	# dates
	b$dates = out$all.dates
		   
	# empty matrix		
	dummy.mat = matrix(double(), len(out$all.dates), nsymbols)
		colnames(dummy.mat) = symbolnames
		dummy.mat = make.xts(dummy.mat, out$all.dates)
		
	# weight matrix holds signal and weight information		
	b$weight = dummy.mat
	
	# execution price, if null use Close	
	b$execution.price = dummy.mat
		
	# populate prices matrix
	for( i in 1:nsymbols ) {
		if( has.Cl( b[[ symbolnames[i] ]] ) ) {
			dummy.mat[,i] = Cl( b[[ symbolnames[i] ]] );
		}
	}
	b$prices = dummy.mat	
}




# matrix form
#' @export 
bt.prep.matrix <- function
(
	b,				# enviroment with symbols time series
	align = c('keep.all', 'remove.na'),	# alignment type
	dates = NULL	# subset of dates
)
{    
	align = align[1]
	nsymbols = len(b$symbolnames)
	
	# merge
	if(!is.null(dates)) { 	
		temp = make.xts(1:len(b$dates), b$dates)
		temp = temp[dates] 
		index = as.vector(temp)
		
		for(i in b$fields) b[[ i ]] = b[[ i ]][index,, drop = FALSE]
		
		b$dates = b$dates[index]
	}
 
	if( align == 'remove.na' ) { 
		index = which(count(b$Cl, side=1) < nsymbols )
	} else {
		index = which(count(b$Cl,side=1) < max(1,0.1 * nsymbols) )
	}
	
	if(len(index) > 0) { 
		for(i in b$fields) b[[ i ]] = b[[ i ]][-index,, drop = FALSE]
		
		b$dates = b$dates[-index]
	}
	
	# empty matrix		
	dummy.mat = make.xts(b$Cl, b$dates)
		
	# weight matrix holds signal and weight information		
	b$weight = NA * dummy.mat
	
	b$execution.price = NA * dummy.mat
	
	b$prices = dummy.mat
}


bt.prep.matrix.test <- function() {
	#*****************************************************************
	# Load historical data
	#****************************************************************** 
	load.packages('quantmod')
	# example csv file holds returns
	# Date ,A,B
	# Jan-70,0.01,0.02
	returns = read.xts('Example.csv', date.fn=function(x) paste('1',x), format='%d %b-%y')
	prices = bt.apply.matrix(1 + returns, cumprod)
	
	data <- new.env()
		data$symbolnames = colnames(prices)
		data$dates = index(prices)
		data$fields = 'Cl'
		data$Cl = prices				
		
	bt.prep.matrix(data)
	
	#*****************************************************************
	# Code Strategies
	#****************************************************************** 
	# Buy & Hold	
	data$weight[] = NA
		data$weight[] = 1
	buy.hold = bt.run.share(data)
	
	#*****************************************************************
	# Create Report
	#****************************************************************** 		
	plotbt(buy.hold, plotX = T, log = 'y', LeftMargin = 3)	    	
			mtext('Cumulative Performance', side = 2, line = 1)
}

###############################################################################
# Remove symbols from enviroment
#' @export 
###############################################################################
bt.prep.remove.symbols.min.history <- function
(
	b, 					# enviroment with symbols time series
	min.history = 1000	# minmum number of observations
) 
{
	bt.prep.remove.symbols(b, which( count(b$prices, side=2) < min.history ))
}

#' @export 
bt.prep.remove.symbols <- function
(
	b, 					# enviroment with symbols time series
	index				# index of symbols to remove
) 
{
	if( len(index) > 0 ) {
		if( is.character(index) ) index = match(index, b$symbolnames)
		 
		b$prices = b$prices[, -index]
		b$weight = b$weight[, -index]
		b$execution.price = b$execution.price[, -index]
		
		rm(list = b$symbolnames[index], envir = b)		
		b$symbolnames = b$symbolnames[ -index]
	}
}

#' @export 
bt.prep.trim <- function
(
	b, 					# enviroment with symbols time series
	dates = NULL	# subset of dates
) 
{	
	if(is.null(dates)) return(b)
	
	data.copy <- new.env()
	for(s in b$symbolnames) data.copy[[s]] = b[[s]][dates,,drop=F]
		 
	data.copy$symbolnames = b$symbolnames
	data.copy$prices = b$prices[dates,,drop=F]
	data.copy$weight = b$weight[dates,,drop=F]
	data.copy$execution.price = b$execution.price[dates,,drop=F]
	return(data.copy)
}
 
###############################################################################
# Helper function to backtest for type='share'
#' @export 
###############################################################################
bt.run.share <- function
(
	b,					# enviroment with symbols time series
	prices = b$prices,	# prices
	clean.signal = T,	# flag to remove excessive signal
	
	trade.summary = F, 	# flag to create trade summary
	do.lag = 1, 		# lag signal
	do.CarryLastObservationForwardIfNA = TRUE, 	
	silent = F,
	capital = 100000,
	commission = 0,
	weight = b$weight,
	dates = 1:nrow(b$prices)	
) 
{
	# make sure that prices are available, assume that
	# weights account for missing prices i.e. no price means no allocation
	prices[] = bt.apply.matrix(coredata(prices), ifna.prev)	

	
	weight = mlag(weight, do.lag - 1)
	do.lag = 1

		
	if(clean.signal) {
		weight[] = (capital / prices) * bt.exrem(weight)
	} else {
		weight[] = (capital / prices) * weight
	}
	
	bt.run(b,
		trade.summary = trade.summary,
		do.lag = do.lag,
		do.CarryLastObservationForwardIfNA = do.CarryLastObservationForwardIfNA,
		type='share',
		silent = silent,
		capital = capital,
		commission = commission,
		weight = weight,
		dates = dates)	
}

###############################################################################
# Run backtest
#
# Inputs are assumed as if they were computed at point in time (i.e. no lags)
#
# For 'weight' back-test, the default action is to lage weights by one day,
# because weights are derived using all the information avalaible today, 
# so we can only implement these weights tomorrow:
#   portfolio.returns = lag(weights,1) * returns = weights * ( p / lag(p,1) - 1 )
# user can specify a different lag for weights, by changing the do.lag parameter.
#
# For example, for the end of the month strategy: if we open position at the close
# on the 30th, hold position on the 31st and sell it at the close on the 1st. If our
# weights have 0 on the 30th, 1 on the 31st, 1 on the 1st, and 0 on the 2nd, we
# can specify do.lag = 0 to get correct portfolio.returns
#
# Alternatively, if our weights have 0 on the 29th, 1 on the 30st, 1 on the 31st, and 0 on the 1nd, we
# can leave do.lag = 1 to get correct portfolio.returns
#
# For 'share' back-test, the portfolio returns:
#   portfolio.returns = lag(shares,1) * ( p - lag(p,1) ) / ( lag(shares,1) * lag(p,1) )
# 
###############################################################################
# some operators do not work well on xts
# weight[] = apply(coredata(weight), 2, ifna_prev)
#' @export 
###############################################################################
bt.run <- function
(
	b,					# enviroment with symbols time series
	trade.summary = F, 	# flag to create trade summary
	do.lag = 1, 		# lag signal
	do.CarryLastObservationForwardIfNA = TRUE, 
	type = c('weight', 'share'),
	silent = F,
	capital = 100000,
	commission = 0,
	weight = b$weight,
	dates = 1:nrow(b$prices)	
) 
{
	# convert dates to dates.index
	dates.index = dates2index(b$prices, dates) 
	
	# setup
	type = type[1]

	# create signal
 weight[] = ifna(weight, NA)

	# lag
 if(do.lag > 0)
		weight = mlag(weight, do.lag) # Note k=1 implies a move *forward*  

	# backfill
	if(do.CarryLastObservationForwardIfNA)
		weight[] = apply(coredata(weight), 2, ifna.prev)

	weight[is.na(weight)] = 0

	# find trades
	weight1 = mlag(weight, -1)
	tstart = weight != weight1 & weight1 != 0
	tend = weight != 0 & weight != weight1
		trade = ifna(tstart | tend, FALSE)
	
	# prices
	prices = b$prices
	
	# execution.price logic
	if( sum(trade) > 0 ) {
		execution.price = coredata(b$execution.price)
		prices1 = coredata(b$prices)
		
		prices1[trade] = iif( is.na(execution.price[trade]), prices1[trade], execution.price[trade] )
		prices[] = prices1
	}
		
	# type of backtest
	if( type == 'weight') {
		ret = prices / mlag(prices) - 1
		ret[] = ifna(ret, NA)
		ret[is.na(ret)] = 0			
	} else { # shares, hence provide prices
		ret = prices
	}
	
	#weight = make.xts(weight, b$dates)
	temp = b$weight
		temp[] = weight
	weight = temp
	
	

	# prepare output
	bt = bt.summary(weight, ret, type, b$prices, capital, commission, dates.index)
		bt$dates.index = dates.index 

	if( trade.summary ) bt$trade.summary = bt.trade.summary(b, bt)

	if( !silent ) {
		# print last signal / weight observation
		cat('Latest weights :\n')
		print(round(100*last(bt$weight),2))
		cat('\n')

		cat('Performance summary :\n')
		cat('', spl('CAGR,Best,Worst'), '\n', sep = '\t')  
    	cat('', sapply(cbind(bt$cagr, bt$best, bt$worst), function(x) round(100*x,1)), '\n', sep = '\t')  
		cat('\n')    
	}
	    
	return(bt)
}

###############################################################################
# Backtest summary
#' @export 
###############################################################################
bt.summary <- function
(
	weight, 	# signal / weights matrix
	ret, 		# returns for type='weight' and prices for type='share'
	type = c('weight', 'share'),
	close.prices,
	capital = 100000,
	commission = 0,	# cents / share commission
	dates.index = 1:nrow(weight)
) 
{
	# cents / share commission
   	#   trade cost = abs(share - mlag(share)) * commission$cps
	# fixed commission per trade to more effectively to penalize for turnover
   	#   trade cost = abs(share - mlag(share)) * commission$cps +  sign(abs(share - mlag(share))) * commission$fixed
	# percentage commission
	#   trade cost = price * abs(share - mlag(share)) * commission$percentage
	if( !is.list(commission) ) {
		if( type == 'weight') 
			commission = list(cps = 0.0, fixed = 0.0, percentage = commission)	
		else 
			commission = list(cps = commission, fixed = 0.0, percentage = 0.0)	
	}
	
	# subset dates
	if(len(dates.index) != nrow(weight)) {
		weight = weight[dates.index,,drop=F]
		ret = ret[dates.index,,drop=F]
		close.prices = close.prices[dates.index,,drop=F]	
	}
	
	
	type = type[1]
    n = nrow(ret)
	     	
    bt = list()
    	bt$weight = weight
    	bt$type = type
    	
	# for commission calculations, un lag the signal
	com.weight = mlag(weight,-1)	
    	
	if( type == 'weight') { 
		temp = ret[,1]
			temp[] = rowSums(ret * weight) - 
				rowSums(abs(com.weight - mlag(com.weight)) * commission$percentage, na.rm=T)
				- rowSums(sign(abs(com.weight - mlag(com.weight))) * commission$fixed, na.rm=T)
		bt$ret = temp
    	#bt$ret = make.xts(rowSums(ret * weight) - rowSums(abs(weight - mlag(weight))*commission, na.rm=T), index.xts(ret))    	
    	#bt$ret = make.xts(rowSums(ret * weight), index.xts(ret))    	
    } else {
    	bt$share = weight
    	bt$capital = capital
    	prices = ret
    		
    	# backfill prices
		#prices1 = coredata(prices)
		#prices1[is.na(prices1)] = ifna(mlag(prices1), NA)[is.na(prices1)]				
		#prices[] = prices1
		prices[] = bt.apply.matrix(coredata(prices), ifna.prev)	
		close.prices[] = bt.apply.matrix(coredata(close.prices), ifna.prev)	
		
		# new logic
		#cash = capital - rowSums(bt$share * mlag(prices), na.rm=T)
		cash = capital - rowSums(bt$share * mlag(close.prices), na.rm=T)
		
			# find trade dates
			share.nextday = mlag(bt$share, -1)
			tstart = bt$share != share.nextday & share.nextday != 0
			tend = bt$share != 0 & bt$share != share.nextday
				trade = ifna(tstart | tend, FALSE)
				tstart = trade
			
			index = mlag(apply(tstart, 1, any))
				index = ifna(index, FALSE)
index[1] = T					
							
			totalcash = NA * cash
				totalcash[index] = cash[index]
			totalcash = ifna.prev(totalcash)
				totalcash = ifna(totalcash,0)	# check this

		
		# We can introduce transaction cost to portfolio returns as
		# abs(bt$share - mlag(bt$share)) * 0.01
		
		portfolio.ret = (totalcash  + rowSums(bt$share * prices, na.rm=T)
							- rowSums(abs(com.weight - mlag(com.weight)) * commission$cps, na.rm=T)
							- rowSums(sign(abs(com.weight - mlag(com.weight))) * commission$fixed, na.rm=T)
							- rowSums(prices * abs(com.weight - mlag(com.weight)) * commission$percentage, na.rm=T)
		 				) / (totalcash + rowSums(bt$share * mlag(prices), na.rm=T) ) - 1		
				
		#portfolio.ret = (totalcash + rowSums(bt$share * prices, na.rm=T) ) / (totalcash + rowSums(bt$share * mlag(prices), na.rm=T) ) - 1				
		
		bt$weight = bt$share * mlag(prices) / (totalcash + rowSums(bt$share * mlag(prices), na.rm=T) )
		

		
		bt$weight[is.na(bt$weight)] = 0		
		#bt$ret = make.xts(ifna(portfolio.ret,0), index.xts(ret))
		temp = ret[,1]
			temp[] = ifna(portfolio.ret,0)
temp[1] = 0
		bt$ret = temp

    }
    	
    bt$best = max(bt$ret)
    bt$worst = min(bt$ret)
    
	bankrupt = which(bt$ret <= -1)
	if(len(bankrupt) > 0) bt$ret[bankrupt[1]:n] = -1
        
    bt$equity = cumprod(1 + bt$ret)
    bt$cagr = compute.cagr(bt$equity)
    	
    return(bt)    
}

bt.summary.test <- function() {
    #*****************************************************************
    # Load historical data
    #******************************************************************
    load.packages('quantmod')

    data <- new.env()
    getSymbols('EEM', src = 'yahoo', from = '1980-01-01', env = data, auto.assign = T)
    
    bt.prep(data, align='keep.all', dates='2013:08::2013:08:10')
	    buy.date = '2013:08:05'
		sell.date = '2013:08:06'
    
    #*****************************************************************
    # Code Strategies
    #******************************************************************    
    # set dummy prices
	coredata(data$prices) <-c(10,20,40,60,20,160,60)
	    prices = data$prices
	
	# weight back-test	
	data$weight[] = NA
	    data$weight[buy.date] = 1
	    data$weight[sell.date] = 0
	    commission = list(cps = 0.0, fixed = 0.0, percentage = 1/100)
	model3 = bt.run(data, commission = commission, silent = T)
	
	model3$ret
	#There is 1% drop on 5th due to buying stock, and on the 6th return is 0.49 = 0.5 - 0.01 (commission)

	
	# share back-test
	data$weight[] = NA
	    data$weight[buy.date] = 1
	    data$weight[sell.date] = 0
	    commission = list(cps = 0.0, fixed = 0.0, percentage = 1/100)
	model3 = bt.run.share(data, commission = commission, capital = 100000, silent = T)

	model3$ret
	#There is 1% drop on 5th due to buying stock, and on the 6th return is 
	#0.485 = (2500 * 60 - 2500 * 60 * 0.01) /  (2500 * 40) - 1
	#i.e. return = (share * price + cash - total.commission) / (share * mlag(price) + cash) - 1

}

###############################################################################
# Remove all leading NAs in model equity
#' @export 
###############################################################################
bt.trim <- function
(
	...,
	dates = '::'
) 
{	
	models = variable.number.arguments( ... )

	for( i in 1:len(models) ) {
		bt = models[[i]]
		
		n = len(bt$equity)
		first = which.max(!is.na(bt$equity) & bt$equity != 1)
		if(first > 1 && !is.na(bt$equity[(first-1)]))
			first = first - 1
		if (first < n) {
			index = first:n

			dates.range = range(dates2index(bt$equity[index],dates))
			index = index[dates.range[1]] : index[dates.range[2]]

			bt$dates.index = bt$dates.index[index]
			bt$equity = bt$equity[index]
				bt$equity = bt$equity / as.double(bt$equity[1])
			bt$ret = bt$ret[index]
			bt$weight = bt$weight[index,,drop=F]
			if (!is.null(bt$share)) bt$share = bt$share[index,,drop=F]

		    bt$best = max(bt$ret)
			bt$worst = min(bt$ret)
			bt$cagr = compute.cagr(bt$equity)
		}
		
		models[[i]] = bt
	}
	return (models)
}


bt.trim.test <- function() {
    #*****************************************************************
    # Load historical data
    #******************************************************************
    load.packages('quantmod')
        
    data <- new.env()
    getSymbols(spl('SPY,GLD'), src = 'yahoo', from = '1980-01-01', env = data, auto.assign = T)
    for(i in ls(data)) data[[i]] = adjustOHLC(data[[i]], use.Adjusted=T)
    bt.prep(data, align='keep.all')

    #*****************************************************************
    # Code Strategies
    #******************************************************************
    models = list()
    
    data$weight[] = NA
        data$weight$SPY[] = 1
    models$SPY = bt.run.share(data, clean.signal=F)

    data$weight[] = NA
        data$weight$GLD[] = 1
    models$GLD = bt.run.share(data, clean.signal=F)
    
    
    strategy.performance.snapshoot(bt.trim(models), T)
}


# bt.run - really fast with no bells or whisles
# working directly with xts is alot slower, so use coredata
#' @export 	
bt.run.weight.fast <- function
(
	b,					# enviroment with symbols time series
	do.lag = 1, 		# lag signal
	do.CarryLastObservationForwardIfNA = TRUE
) 
{
    # Signal => weight
    weight = ifna(coredata(b$weight), NA)
    
    # lag
    if(do.lag > 0) weight = mlag(weight, do.lag) # Note k=1 implies a move *forward*  
	
	# backfill
	if(do.CarryLastObservationForwardIfNA) weight[] = apply(coredata(weight), 2, ifna.prev)
    
	weight[is.na(weight)] = 0

	# returns
	prices = coredata(b$prices)
	ret = prices / mlag(prices) - 1
		ret[] = ifna(ret, 0)
	ret = rowSums(ret * weight)
	
	# prepare output
    list(weight = weight, ret = ret, equity = cumprod(1 + ret))
}

###############################################################################
# Portfolio turnover	
# http://wiki.fool.com/Portfolio_turnover
# sales or purchases and dividing it by the average monthly value of the fund's assets
#' @export 
###############################################################################
compute.turnover <- function
(	
	bt,		# backtest object
	b 		# enviroment with symbols time series
) 
{ 
	year.ends =  unique(c(endpoints(bt$weight, 'years'), nrow(bt$weight)))	
		year.ends = year.ends[year.ends>0]	
		nr = len(year.ends)
	period.index = c(1, year.ends)

	
	if( bt$type == 'weight') {    	    	
		portfolio.value = rowSums(abs(bt$weight), na.rm=T)
		portfolio.turnover = rowSums( abs(bt$weight - mlag(bt$weight)), na.rm=T) 
		portfolio.turnover[ rowSums( !is.na(bt$weight) & !is.na(mlag(bt$weight)) ) == 0 ] = NA
	} else {
		prices = mlag(b$prices[bt$dates.index,,drop=F])
		# logic from bt.summary function				
		cash = bt$capital - rowSums(bt$share * prices, na.rm=T)
		
			# find trade dates
			share.nextday = mlag(bt$share, -1)
			tstart = bt$share != share.nextday & share.nextday != 0
			
			index = mlag(apply(tstart, 1, any))
				index = ifna(index, FALSE)
								
			totalcash = NA * cash
				totalcash[index] = cash[index]
			totalcash = ifna.prev(totalcash)
		
		portfolio.value = totalcash + rowSums(bt$share * prices, na.rm=T)
		
		portfolio.turnover = rowSums( prices * abs(bt$share - mlag(bt$share)), na.rm=T)
		portfolio.turnover[ rowSums( !is.na(bt$share) & !is.na(mlag(bt$share)) & !is.na(prices) ) == 0 ] = NA
	}
	
	portfolio.turnover[1:2] = 0
	temp = NA * period.index			
	for(iyear in 2:len(period.index)) {
		temp[iyear] = sum( portfolio.turnover[ period.index[(iyear-1)] : period.index[iyear] ], na.rm=T) / 
						mean( portfolio.value[ period.index[(iyear-1)] : period.index[iyear] ], na.rm=T)			
	}
	return( ifna(mean(temp, na.rm=T),0) )			
}


###############################################################################
# Compute Portfolio Maximum Deviation
#' @export 
###############################################################################
compute.max.deviation <- function
(
	bt,
	target.allocation
)
{
	weight = bt$weight[-1,]
	max(abs(weight - repmat(target.allocation, nrow(weight), 1)))
}

###############################################################################
# Backtest Trade summary
#' @export 
###############################################################################
bt.trade.summary <- function
(
	b, 		# enviroment with symbols time series
	bt		# backtest object
)
{    
	if( bt$type == 'weight') weight = bt$weight else weight = bt$share
	
	out = NULL
	
	# find trades
	weight1 = mlag(weight, -1)
	tstart = weight != weight1 & weight1 != 0
	tend = weight != 0 & weight != weight1	
		tstart[1, weight[1,] != 0] = T
		trade = ifna(tstart | tend, FALSE)
	
	# prices
	prices = b$prices[bt$dates.index,,drop=F]
	
	# execution price logic
	if( sum(trade) > 0 ) {
		execution.price = coredata(b$execution.price[bt$dates.index,,drop=F])
		prices1 = coredata(b$prices[bt$dates.index,,drop=F])
		
		prices1[trade] = iif( is.na(execution.price[trade]), prices1[trade], execution.price[trade] )
		
		# backfill pricess
		prices1[is.na(prices1)] = ifna(mlag(prices1), NA)[is.na(prices1)]				
		prices[] = prices1
			
		# get actual weights
		weight = bt$weight
	
		# extract trades
		symbolnames = b$symbolnames
		nsymbols = len(symbolnames) 	

		trades = c()
		for( i in 1:nsymbols ) {	
			tstarti = which(tstart[,i])
			tendi = which(tend[,i])
			
			if( len(tstarti) > 0 ) {
				if( len(tendi) < len(tstarti) ) tendi = c(tendi, nrow(weight))
				if( len(tendi) > len(tstarti) ) tstarti = c(1, tstarti)
				
				trades = rbind(trades, 
								cbind(i, weight[(tstarti+1), i], 
								tstarti, tendi, tendi-tstarti,
								as.vector(prices[tstarti, i]), as.vector(prices[tendi,i])
								)
							)
			}
		}
		colnames(trades) = spl('symbol,weight,entry.date,exit.date,nhold,entry.price,exit.price')

		
		# prepare output		
		out = list()
		out$stats = cbind(
			bt.trade.summary.helper(trades),
			bt.trade.summary.helper(trades[trades[, 'weight'] >= 0, ]),
			bt.trade.summary.helper(trades[trades[, 'weight'] <0, ])
		)
		colnames(out$stats) = spl('All,Long,Short')
		
		temp.x = index.xts(weight)
		
		trades = data.frame(coredata(trades))
			trades$symbol = symbolnames[trades$symbol]
			trades$nhold = as.numeric(temp.x[trades$exit.date] - temp.x[trades$entry.date])
			trades$entry.date = temp.x[trades$entry.date]
			trades$exit.date = temp.x[trades$exit.date]			
			trades$return = round(100*(trades$weight) * (trades$exit.price/trades$entry.price - 1),2)			
			trades$entry.price = round(trades$entry.price, 2)
			trades$exit.price = round(trades$exit.price, 2)			
			trades$weight = round(100*(trades$weight),1)		

		out$trades = as.matrix(trades)				
	}
	
	return(out)
}

# helper function
#' @export 
bt.trade.summary.helper <- function(trades) 
{		
	if(nrow(trades) <= 0) return(NA)
	
	out = list()
		tpnl = trades[, 'weight'] * (trades[, 'exit.price'] / trades[,'entry.price'] - 1)
		tlen = trades[, 'exit.date'] - trades[, 'entry.date']
		
	out$ntrades = nrow(trades)
	out$avg.pnl = mean(tpnl)
	out$len = mean(tlen)
		
	out$win.prob = len(which( tpnl > 0 )) / out$ntrades
	out$win.avg.pnl = mean( tpnl[ tpnl > 0 ])
	out$win.len = mean( tlen[ tpnl > 0 ])
		
	out$loss.prob = 1 - out$win.prob
	out$loss.avg.pnl = mean( tpnl[ tpnl < 0 ])
	out$loss.len = mean( tlen[ tpnl < 0 ])
		
	#Van Tharp : Expectancy = (PWin * AvgWin) - (PLoss * AvgLoss)			
	out$expectancy = (out$win.prob * out$win.avg.pnl + out$loss.prob * out$loss.avg.pnl)/100
			
	# Profit Factor is computed as follows: (PWin * AvgWin) / (PLoss * AvgLoss)
	out$profitfactor = -(out$win.prob * out$win.avg.pnl) / (out$loss.prob * out$loss.avg.pnl)			
			
	return(as.matrix(unlist(out)))
}		

###############################################################################
# Apply given function to bt enviroment
#' @export 
###############################################################################
bt.apply <- function
(
	b,			# enviroment with symbols time series
	xfun=Cl,	# user specified function
	...			# other parameters
)
{
	out = b$weight
	out[] = NA
	
	symbolnames = b$symbolnames
	nsymbols = length(symbolnames) 
	
	for( i in 1:nsymbols ) {	
		msg = try( match.fun(xfun)( coredata(b[[ symbolnames[i] ]]),... ) , silent=TRUE)
		if (class(msg)[1] != 'try-error') {
			out[,i] = msg
		} else {
			warning(i, msg, '\n')
		}
	}
	return(out)
}

#' @export 
bt.apply.matrix <- function
(
	b,			# matrix
	xfun=Cl,	# user specified function
	...			# other parameters
)
{
	out = b
	out[] = NA
	nsymbols = ncol(b)
	
	for( i in 1:nsymbols ) {	
		msg = try( match.fun(xfun)( coredata(b[,i]),... ) , silent=TRUE);
		if (class(msg)[1] != 'try-error') {
			out[,i] = msg
		} else {
			warning(i, msg, '\n')
		}
	}
	return(out)
}

###############################################################################
# Remove excessive signal
# http://www.amibroker.com/guide/afl/exrem.html
#' @export 
###############################################################################
exrem <- function(x) {        
    temp = c(0, ifna(ifna.prev(x),0))
        itemp = which(temp != mlag(temp))
    x[] = NA
    x[(itemp-1)] = temp[itemp]    
    return(x)
}

exrem.test <- function() {
	exrem(c(NA,1,1,0,1,1,NA,0))
}

#' @export 
bt.exrem <- function(weight)
{
    bt.apply.matrix(weight, exrem)
}


###############################################################################
# Backtest Test function
###############################################################################
bt.test <- function()
{
	load.packages('quantmod')
	
	#*****************************************************************
	# Load historical data
	#****************************************************************** 
	
	tickers = spl('SPY')

	data <- new.env()
	getSymbols(tickers, src = 'yahoo', from = '1970-01-01', env = data, auto.assign = T)
	bt.prep(data, align='keep.all', dates='1970::2011')

	#*****************************************************************
	# Code Strategies
	#****************************************************************** 

	prices = data$prices    
	
	# Buy & Hold	
	data$weight[] = 1
	buy.hold = bt.run(data)	

	# MA Cross
	sma = bt.apply(data, function(x) { SMA(Cl(x), 200) } )	
	data$weight[] = NA
		data$weight[] = iif(prices >= sma, 1, 0)
	sma.cross = bt.run(data, trade.summary=T)			

	#*****************************************************************
	# Create Report
	#****************************************************************** 
		
					
png(filename = 'plot1.png', width = 600, height = 500, units = 'px', pointsize = 12, bg = 'white')										
	plotbt.custom.report.part1( sma.cross, buy.hold)			
dev.off()	


png(filename = 'plot2.png', width = 1200, height = 800, units = 'px', pointsize = 12, bg = 'white')	
	plotbt.custom.report.part2( sma.cross, buy.hold)			
dev.off()	
	

png(filename = 'plot3.png', width = 600, height = 500, units = 'px', pointsize = 12, bg = 'white')	
	plotbt.custom.report.part3( sma.cross, buy.hold)			
dev.off()	




	# put all reports into one pdf file
	pdf(file = 'report.pdf', width=8.5, height=11)
		plotbt.custom.report(sma.cross, buy.hold, trade.summary=T)
	dev.off()	

	#*****************************************************************
	# Code Strategies
	#****************************************************************** 
	
	data$weight[] = NA
		data$weight$SPY = 1
	temp = bt.run(data)

	data$weight[] = NA
		data$weight$SPY = 2
	temp = bt.run(data)

	data$weight[] = NA
		data$weight$SPY = 1
		capital = 100000
		data$weight[] = (capital / prices) * data$weight
	temp = bt.run(data, type='share', capital=capital)

	data$weight[] = NA
		data$weight$SPY = 2
		capital = 100000
		data$weight[] = (capital / prices) * data$weight
	temp = bt.run(data, type='share', capital=capital)
	
}

###############################################################################
# Analytics Functions
###############################################################################
# CAGR - geometric return
#' @export 
###############################################################################
compute.cagr <- function(equity, nyears = NA) 
{
	if(is.numeric(nyears))
		as.double( last(equity,1)^(1/nyears) - 1 )
	else 
		as.double( last(equity,1)^(1/compute.nyears(equity)) - 1 )
}

#' @export 
compute.nyears <- function(x) 
{
	as.double(diff(as.Date(range(index.xts(x)))))/365
}

#' @export 
compute.raw.annual.factor = function(x) {
	round( nrow(x) / compute.nyears(x) )
}

# 252 - days, 52 - weeks, 26 - biweeks, 12-months, 6,4,3,2,1
#' @export 
compute.annual.factor = function(x) {
	possible.values = c(252,52,26,13,12,6,4,3,2,1)
	index = which.min(abs( compute.raw.annual.factor(x) - possible.values ))
	round( possible.values[index] )
}

#' @export 
compute.sharpe <- function(x) 
{ 
	temp = compute.annual.factor(x)
	x = as.vector(coredata(x))
	return(sqrt(temp) * mean(x)/sd(x) )
}

# http://alumnus.caltech.edu/~amir/mdd-risk.pdf
# The Calmar Ratio is equal to the compounded annual growth rate divided by the maximum drawdown.
# The maximum drawdown is typically measured over a three year period.
# Calmar Ratio = CAGR / MAXDD
#' @export 
compute.calmar <- function(x)
{
    compute.cagr(x) / compute.max.drawdown(x)
}

# R2 equals the square of the correlation coefficient
#' @export 
compute.R2 <- function(equity) 
{
	x = as.double(index.xts(equity))
	y = equity
	#summary(lm(y~x))
	return( cor(y,x)^2 )
}

# http://cssanalytics.wordpress.com/2009/10/15/ft-portfolio-with-dynamic-hedging/
# DVR is the Sharpe Ratio times the R-squared of the equity curve
#' @export 
compute.DVR <- function(bt) 
{
	return( compute.sharpe(bt$ret) * compute.R2(bt$equity) )
}

#' @export 
compute.risk <- function(x) 
{ 
	temp = compute.annual.factor(x)
	x = as.vector(coredata(x))
	return( sqrt(temp)*sd(x) ) 
}

#' @export 
compute.drawdown <- function(x) 
{ 
	return(x / cummax(c(1,x))[-1] - 1)
}

#' @export 
compute.max.drawdown <- function(x) 
{ 
	as.double( min(compute.drawdown(x)) )
}

#' @export 
compute.avg.drawdown <- function(x) 
{ 
	drawdown = c( 0, compute.drawdown(coredata(x)), 0 )
	dstart = which( drawdown == 0 & mlag(drawdown, -1) != 0 )
	dend = which(drawdown == 0 & mlag(drawdown, 1) != 0 )
	drawdowns = apply( cbind(dstart, dend), 1, function(x) min(drawdown[ x[1]:x[2] ], na.rm=T) )
	mean(drawdowns)
}

#' @export 
compute.cdar <- function(x, probs=0.05) 
{ 
	drawdown = c( 0, compute.drawdown(coredata(x)), 0 )
	dstart = which( drawdown == 0 & mlag(drawdown, -1) != 0 )
	dend = which(drawdown == 0 & mlag(drawdown, 1) != 0 )
	drawdowns = apply( cbind(dstart, dend), 1, function(x) min(drawdown[ x[1]:x[2] ], na.rm=T) )
	if(len(drawdowns)>2)
		mean( drawdowns[ drawdowns < quantile(drawdowns, probs=probs) ] )
	else
		min(drawdowns)
}	

#' @export 
compute.exposure <- function(weight) 
{ 
	sum( apply(weight, 1, function(x) sum(x != 0) ) != 0 ) / nrow(weight) 
}

#' @export 
compute.var <- function(x, probs=0.05) 
{ 
	quantile( coredata(x), probs=probs)
}

#' @export 
compute.cvar <- function(x, probs=0.05) 
{ 
	x = coredata(x)
	mean( x[ x < quantile(x, probs=probs) ] )
}

#' @export 
compute.stats <- function(data, fns, do.na.omit = T) 
{
	out = matrix(double(), len(fns), len(data))
		colnames(out) = names(data)
		rownames(out) = names(fns)
if( do.na.omit )
	for(c in 1:len(data)) {
		for(r in 1:len(fns)) {
			out[r,c] = match.fun(fns[[r]])( fast.na.omit(data[[c]]) )
		}
	}
else
	for(c in 1:len(data)) {
		for(r in 1:len(fns)) {
			out[r,c] = match.fun(fns[[r]])( data[[c]] )
		}
	}

	return(out)
}

###############################################################################
# Example to illustrate a simeple backtest
#' @export 
###############################################################################
bt.simple <- function(data, signal, silent = F) 
{
	# lag singal
	signal = Lag(signal, 1)

	# back fill
    signal = na.locf(signal, na.rm = FALSE)
	signal[is.na(signal)] = 0

	# calculate Close-to-Close returns
	ret = ROC(Cl(data), type='discrete')
	ret[1] = 0
	
	# compute stats	
    n = nrow(ret)
    bt <- list()
    	bt$ret = ret * signal
    	bt$best = max(bt$ret)
    	bt$worst = min(bt$ret)
    	bt$equity = cumprod(1 + bt$ret)
    	bt$cagr = bt$equity[n] ^ (1/nyears(data)) - 1
    
    # print
    if( !silent) {
	cat('', spl('CAGR,Best,Worst'), '\n', sep = '\t')  
    cat('', sapply(cbind(bt$cagr, bt$best, bt$worst), function(x) round(100*x,1)), '\n', sep = '\t')  
    }
    	    	
	return(bt)
}

bt.simple.test <- function()
{
	load.packages('quantmod')
	
	# load historical prices from Yahoo Finance
	data = getSymbols('SPY', src = 'yahoo', from = '1980-01-01', auto.assign = F)

	# Buy & Hold
	signal = rep(1, nrow(data))
    buy.hold = bt.simple(data, signal)
        
	# MA Cross
	sma = SMA(Cl(data),200)
	signal = ifelse(Cl(data) > sma, 1, 0)
    sma.cross = bt.simple(data, signal)
        
	# Create a chart showing the strategies perfromance in 2000:2009
	dates = '2000::2009'
	buy.hold.equity <- buy.hold$equity[dates] / as.double(buy.hold$equity[dates][1])
	sma.cross.equity <- sma.cross$equity[dates] / as.double(sma.cross$equity[dates][1])

	chartSeries(buy.hold.equity, TA=c(addTA(sma.cross.equity, on=1, col='red')),	
	theme ='white', yrange = range(buy.hold.equity, sma.cross.equity) )	
}

###############################################################################
#' Remove small weights
#'
#' This function will remove weights that are smaller than given threshold
#'
#' @param weight weight matrix
#' @param long.min.weight minimum weight for long positions, \strong{defaults to 0.1 }
#' @param short.min.weight minimum weight for short positions, \strong{defaults to long.min.weight }
#'
#' @return updated weight matrix
#'
#' @examples
#' \dontrun{ 
#' weight = c(0.1, 0.6, 0.2, 0.1, 0, -0.1, -0.6, -0.2, -0.1, 0)
#' weight = matrix(weight, nrow=2, byrow=TRUE)
#' print(bt.apply.min.weight(weight, 0.1))
#' }
#' @author Ivan Popivanov and Michael Kapler
#' @export 
###############################################################################
# Possible use
#   if(!missing(min.weight)) {
#      for(i in names(obj$weights)) {
#         obj$weights[[i]] = apply.min.weight(obj$weights[[i]], min.weight)
#      }    
#   }
###############################################################################
bt.apply.min.weight <- function
(
	weight, 
	long.min.weight = 0.1, 
	short.min.weight = long.min.weight
)
{
	# make sure weight is a matrix
	if(is.null(dim(weight))) dim(weight) = c(1, len(weight))
    
	# in each row, compute total pos/neg weights
	pos = apply(weight, 1, function(row) sum(row[row > 0]))
	neg = rowSums(weight) - pos
    
	# setup
	pos.mat = iif(weight >= long.min.weight, weight, 0)
	neg.mat = iif(weight <= -short.min.weight, weight, 0)
    
	# re-scale
	pos.mat = pos.mat * ifna(pos / rowSums(pos.mat), 1)
	neg.mat = neg.mat * ifna(neg / rowSums(neg.mat), 1)
    
	return(pos.mat + neg.mat)
} 

test.bt.apply.min.weight <- function()
{
	data = c(0.1, 0.6, 0.2, 0.1, 0, -0.1, -0.6, -0.2, -0.1, 0)
	mm = matrix(data=data, nrow=2, byrow=TRUE)
	print(bt.apply.min.weight(mm, 0.1))
	print(bt.apply.min.weight(mm, 0.2))
   
	data = c(0.1, 0.6, 0.2, 0.1, 0, -0.1, -0.6, -0.2, -0.1, 0)
	mm = matrix(data=data, nrow=1, byrow=TRUE)
	print(bt.apply.min.weight(mm, 0.1))
	print(bt.apply.min.weight(mm, 0.2))
   
	data = c(0.1, 0.6, 0.2, 0.1, 0, -0.2, -0.5, -0.3, -0.1, 0)
	mm = matrix(data=data, nrow=1, byrow=TRUE)
	print(bt.apply.min.weight(mm, 0.1))
	print(bt.apply.min.weight(mm, 0.2))
}

###############################################################################
#' Round weights
#' 
#' Similar idea to bt.apply.min.weight
#' 
#' @export 
###############################################################################
bt.apply.round.weight <- function
(
	weight, 
	long.round.weight = 5/100, 
	short.round.weight = long.round.weight
)
{
	# make sure weight is a matrix
	if(is.null(dim(weight))) dim(weight) = c(1, len(weight))
    
	# in each row, compute total pos/neg weights
	pos = apply(weight, 1, function(row) sum(row[row > 0]))
	neg = rowSums(weight) - pos
    
	# setup
	pos.mat = iif(weight >= 0, round(weight / long.round.weight) * long.round.weight, 0)
	neg.mat = iif(weight <= 0, round(weight / short.round.weight) * short.round.weight, 0)
    
	# re-scale
	pos.mat = pos.mat * ifna(pos / rowSums(pos.mat), 1)
	neg.mat = neg.mat * ifna(neg / rowSums(neg.mat), 1)
    
	return(pos.mat + neg.mat)
} 

###############################################################################
#' Print starting dates for time series
#' 
#' @export 
###############################################################################
bt.start.dates <- function
(
	b 					# enviroment with symbols time series
) 
{
	temp = lapply(b, function(x) index(x[1]) )
		temp$dates = NULL
		temp$prices = NULL
		temp$weight = NULL
		temp$execution.price = NULL
		temp$symbolnames = NULL
	temp = temp[order( sapply(temp, function(x) x) )]
	
	out = t(t( sapply(temp, function(x) as.character(x)) ))
    colnames(out) = 'Start'
  out
}
	

###############################################################################
#' Append today's quotes
#' 
#' data.today = getQuote.yahoo.today(ls(data))
#' 	print(data.today)
#' bt.append.today(data, data.today)
#' 
#' @export 
###############################################################################
bt.append.today <- function(b, data.today) {
	tickers = data.today$Symbol
	Yesterday = data.today$Yesterday	
	data = make.stock.xts(read.xts(data.today, date.column=find.names('Date',data.today),format='%m/%d/%Y', decreasing=NULL))
	
	# todo, better logic for merging Intraday and EOD data
	for(i in 1:len(tickers)) {
		if(is.null(b[[ tickers[i] ]])) next
		if( last(index(data[i,])) > last(index(b[[ tickers[i] ]])) )
			b[[ tickers[i] ]] = rbind(data[i,], b[[ tickers[i] ]])
		#b[[ tickers[i] ]] = extend.data(env[[ s ]], data[[ gsub('\\^', '', map[[ s ]][i]) ]], scale=T)
	}
}
