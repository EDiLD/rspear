#' Calculate SPEAR values
#'
#' @include match_traits.R
#' @include get_traits.R
#' @import plyr
#' 
#' @param x  data.frame; data.frame with abundances in the long format.
#' @param taxa character; name of column in x, which holdes the taxon-names.
#' @param abundance character string: columnname of abundances
#' @param group character-vector; names of columns for groupings.
#' @param region character; default is set to 'Eurasia', which covers trait-data 
#' for Finland, United Kingdom, West Siberia and Central Europe. 'Finland', 
#' 'United Kingdom', 'West Siberia' are also allowed and traits may vary 
#' between different regions.
#' @param traits NULL or data.frame; If 'NULL' (default) then it is checked if 
#' there is a file 'traits.csv' in the working directory and if this file is 
#' up-to-date with the database, see \code{\link{get_traits}}.
#' If there is no such file, it is downloaded from the web-server. 
#' If it is a data.frame, this is used as trait-data 
#' (after checking if appropiate).
#' @param sensitivity numeric; sensitivity-threshold, default '-0.36'
#' @param generationTime numeric; Generation Time threshold, default '0.5'
#' @param exposed logical; either '1' (exposed) or '0' (not exposed), default '1'
#' @param migration logical; either '1' (migration) '0' (no migration), default '0'
#' @param ... additional arguments passed to get_traits. Currently only 'check' is available.
#' By default the file is checked if up-to-date. See \code{\link{get_traits}}.
#' 
#' @details
#' The SPEAR index is based on binary classification of species (or other taxonomic categories) into 'species at risk' and 'species not at risk' according to the following biological traits: 
#' \itemize{
#' \item physiological sensitivity to organic toxicant
#' \item generation time
#' \item presence of aquatic stages in water during the maximum pesticide usage period
#' \item migration abilities. 
#' }
#' A taxon is classified as a 'SPEcies At Risk' only if it has: (i) Sorganic value >-0.36, (ii) generation time >= 0.5 year, aquatic stages (eggs, larvae, pupae) during the periods of intensive pesticide usage, and (iv) low migration abilities. 
#' 
#' The SPEARpesticides index is computed as relative abundance of these taxa for each site and date as follows:
#' 
#' \deqn{SPEAR = \sum log10(x[i] + 1) * y / \sum log10(x[i] + 1)}
#' 
#' where x[i] is the abundance of the taxon i and y is 1 if taxon i is classified as 'at risk', otherwise 0. 
#' 
#' For further details about SPEARpesticides see References.
#' 
#' @note Threshold-values for classification into SPEAR should only be changed 
#' if there is strong indication that they are different than these defaults!
#' 
#' @seealso \code{\link{get_traits}}
#'  
#' @return A list of two data.frames:
#' \item{spear}{data.frame; SPEAR-values for every combination of the grouping variables.}
#' \item{traits}{a data.frame with the following columns:}
#' 
#'   \item{region, exposed, generationTime, sensitivity, migration}{species traits used to classify 
#'   species into SPEAR.}
#'   \item{SPEAR}{Classification of species into SPEAR.}
#'   \item{taxa_data}{taxon names as in x.}
#'   \item{taxa_matched}{matched taxon-names in traits-database.}
#'   \item{match_val}{goodnes of match. '-1' indicates a direct match, 
#'   'NA' indicates a failed match. Values betweenn 0 and 0.5 indicate an 
#'   approximate match (smaller values - better match).}
#'  
#' 
#' @references 
#' Liess M, Von der Ohe P, 2005. Analyzing effects of pesticides on invertebrate communities in streams. \emph{Environmental Toxicology and Chemistry}, 24, 954-965.
#' 
#' Liess M, Schaefer R, Schriever C, 2008. The footprint of pesticide stress in communities - species traits reveal community effects of toxicants. \emph{Science of the Total Environment}, 406, 484-490.
#' 
#' @author Eduard Szoecs \email{eduardszoecs@@gmail.com}
#' @export
#' @examples
#' require(rspear)
#' data(spear_example)
#' head(spear_example)
#' sp <- spear(spear_example ,
#'    taxa = "Taxon", 
#'    abundance = "Abundance", 
#'    group = c("Year", "Site"),
#'    check = FALSE)
#' sp$traits
#' sp$spear
spear <- function(x, taxa = NULL, abundance = NULL,  group = NULL, 
                  region = "Eurasia", traits = NULL,
                  sensitivity = -0.36, generationTime = 0.5, exposed = 1, 
                  migration = 0, ...){
  # Check User Input
  if(!taxa %in% names(x))
    stop("Column '", taxa, "' not found in data!\n
         Please check colnames.")
  if(!abundance %in% names(x))
    stop("Column '", abundance, "' not found in data!\n
         Please check colnames.")
  if(!all(group %in% names(x)))
    stop("Group-column not found in data!\n
         Please check colnames.")
  if(is.null(traits)){
    # = get trait-table
    traits <- get_traits(...)
    db_match <- match_traits(x = x, y = traits, takex = taxa, takey = "name")
    trait <- cbind(db_match, traits[match(db_match$taxa_matched, traits$name), -1])
    if(any(is.na(trait$taxa_matched)))
      warning("There were unmatched species:\n", trait$taxa_data[is.na(trait$taxa_matched)], "\nSet SPEAR to 0.")
    if(any(trait$match_val > 0))
      warning("Non-direct taxon matches!\nCheck trait table if match is appropiate!!")
    trait$SPEAR <- ifelse(trait$sensitivity > sensitivity & 
                            trait$generationTime >= generationTime & 
                            trait$exposed == exposed & 
                            trait$migration == migration, 1, 0)
    trait$SPEAR[is.na(trait$taxa_matched)] <- 0
  } else {
    # = take this as trait tables
    if(!any(class(traits) == "spear"))
      stop("traits must be of class 'spear'!")
    trait <- traits
    trait$SPEAR <- ifelse(trait$sensitivity > sensitivity & 
                            trait$generationTime >= generationTime & 
                            trait$exposed == exposed & 
                            trait$migration == migration, 1, 0)
    trait$SPEAR[is.na(trait$SPEAR)] <- 0
  }
  df <- merge(x, trait, by.x = taxa, by.y = "taxa_data")
  spear <- ddply(df, group, function(x) c(SPEAR = 100 * sum(log(x[ , abundance] + 1) * x$SPEAR) / sum(log(x[ , abundance] + 1))))
  out = list(spear = spear, 
             traits = trait[order(trait$match_val, decreasing = TRUE, na.last = FALSE), c("taxa_data", "taxa_matched", "match_val", "region", "exposed", "generationTime", "sensitivity", "migration", "SPEAR")])
  class(out$traits) <- c("data.frame", "spear")
  return(out)
}