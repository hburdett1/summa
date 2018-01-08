! SUMMA - Structure for Unifying Multiple Modeling Alternatives
! Copyright (C) 2014-2015 NCAR/RAL
!
! This file is part of SUMMA
!
! For more information see: http://www.ral.ucar.edu/projects/summa
!
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

! used to manage output statistics of the model and forcing variables
module output_stats
USE nrtype, realMissing=>nr_realMissing
USE nrtype, integerMissing=>nr_integerMissing
implicit none
private
public :: calcStats
contains

 ! ******************************************************************************************************
 ! public subroutine calcStats is called at every model timestep to update/store output statistics
 ! from model variables
 ! ******************************************************************************************************
 subroutine calcStats(stat,dat,meta,iStep,err,message)
 USE nrtype
 USE data_types,only:extended_info,dlength,ilength  ! metadata structure type
 USE var_lookup,only:iLookVarType                   ! named variables for variable types
 USE var_lookup,only:iLookStat                      ! named variables for output statistics types
 implicit none

 ! dummy variables
 type(dlength) ,intent(inout)   :: stat(:)          ! statistics
 class(*)      ,intent(in)      :: dat(:)           ! data
 type(extended_info),intent(in) :: meta(:)          ! metadata
 integer(i4b)  ,intent(in)      :: iStep            ! timestep index to compare with oFreq of each variable
 integer(i4b)  ,intent(out)     :: err              ! error code
 character(*)  ,intent(out)     :: message          ! error message

 ! internals
 character(256)                 :: cmessage         ! error message
 integer(i4b)                   :: iVar             ! index for varaiable loop
 integer(i4b)                   :: pVar             ! index into parent structure
 real(dp)                       :: tdata            ! dummy for pulling info from dat structure

 ! initialize error control
 err=0; message='calcStats/'

 ! loop through variables
 do iVar = 1,size(meta)

  ! don't do anything if var is not requested
  if (.not.meta(iVar)%varDesire) cycle

  ! only treat stats of scalars - all others handled separately
  if (meta(iVar)%varType==iLookVarType%outstat) then

   ! index in parent structure
   pVar = meta(iVar)%ixParent

   ! extract data from the structures
   select type (dat)
    type is (real(dp));  tdata = dat(pVar)
    class is (dlength) ; tdata = dat(pVar)%dat(1)
    class is (ilength) ; tdata = real(dat(pVar)%dat(1), kind(dp))
    class default;err=20;message=trim(message)//'dat type not found';return
   end select

   ! calculate statistics
   if (trim(meta(iVar)%varName)=='time') then
    stat(iVar)%dat(iLookStat%inst) = tdata
   else
    call calc_stats(meta(iVar),stat(iVar),tdata,iStep,err,cmessage)
   end if
   if(err/=0)then; message=trim(message)//trim(cmessage);return; end if

  end if  ! if calculating statistics
 end do  ! looping through variables

 return
 end subroutine calcStats


 ! ***********************************************************************************
 ! Private subroutine calc_stats is a generic fucntion to deal with any variable type.
 ! Called from compile_stats
 ! ***********************************************************************************
 subroutine calc_stats(meta,stat,tdata,iStep,err,message)
 USE nrtype
 ! data structures
 USE data_types,only:var_info,ilength,dlength ! type dec for meta data structures
 USE var_lookup,only:maxVarFreq       ! # of output frequencies
 USE globalData,only:outFreq          ! output frequencies
 ! global variables
 USE globalData,only:data_step        ! forcing timestep
 ! structures of named variables
 USE var_lookup,only:iLookVarType     ! named variables for variable types
 USE var_lookup,only:iLookStat        ! named variables for output statistics types
 implicit none
 ! dummy variables
 class(var_info),intent(in)        :: meta        ! meta dat a structure
 class(*)       ,intent(inout)     :: stat        ! statistics structure
 real(dp)       ,intent(in)        :: tdata       ! data structure
 integer(i4b)   ,intent(in)        :: iStep       ! timestep
 integer(i4b)   ,intent(out)       :: err         ! error code
 character(*)   ,intent(out)       :: message     ! error message
 ! internals
 real(dp),dimension(maxvarFreq*2)  :: tstat       ! temporary stats vector
 integer(i4b)                      :: iFreq       ! statistics loop
 logical(lgt)                      :: resetStatistics     ! flag to reset the statistics
 logical(lgt)                      :: finalizeStatistics  ! flag to finalize the statistics
 ! initialize error control
 err=0; message='calc_stats/'

 ! extract variable from the data structure
 select type (stat)
  class is (ilength); tstat = real(stat%dat)
  class is (dlength); tstat = stat%dat
  class default;err=20;message=trim(message)//'stat type not found';return
 end select

 ! define the need to reset statistics
 ! NOTE: need to fix this
 resetStatistics=.true.
 finalizeStatistics=.true.
 print*, 'iStep = ', iStep

 ! ---------------------------------------------
 ! reset statistics at new frequency period
 ! ---------------------------------------------
 if(resetStatistics)then
  do iFreq=1,maxVarFreq                             ! loop through output statistics
   if(meta%statIndex(iFreq)==integerMissing) cycle  ! don't bother if output frequency is not desired for a given variab;e
   if(meta%varType/=iLookVarType%outstat) cycle     ! only calculate stats for scalars
   select case(meta%statIndex(iFreq))               ! act depending on the statistic
    ! -------------------------------------------------------------------------------------
    case (iLookStat%totl)                           ! * summation over period                  
     tstat(iFreq) = 0._dp                           !     - resets stat at beginning of period
    case (iLookStat%mean)                           ! * mean over period                       
     tstat(iFreq) = 0._dp                           !     - resets stat at beginning of period
    case (iLookStat%vari)                           ! * variance over period                   
     tstat(iFreq) = 0._dp                           !     - resets E[X^2] term in var calc    
     tstat(maxVarFreq+iFreq) = 0._dp                !     - resets E[X]^2 term                 
    case (iLookStat%mini)                           ! * minimum over period                    
     tstat(iFreq) = huge(tstat(iFreq))              !     - resets stat at beginning of period 
    case (iLookStat%maxi)                           ! * maximum over period                    
     tstat(iFreq) = -huge(tstat(iFreq))             !     - resets stat at beginning of period 
    case (iLookStat%mode)                           ! * mode over period (does not work)       
     tstat(iFreq) = realMissing
    ! -------------------------------------------------------------------------------------
   end select
  end do ! looping through output frequencies
 end if

 ! ---------------------------------------------
 ! Calculate each statistic that is requested by user
 ! ---------------------------------------------
 do iFreq=1,maxVarFreq                                ! loop through output statistics
  if(meta%statIndex(iFreq)==integerMissing) cycle     ! don't bother if output frequency is not desired for a given variab;e
  if(meta%varType/=iLookVarType%outstat) cycle        ! only calculate stats for scalars
  select case(meta%statIndex(iFreq))                  ! act depending on the statistic
   ! -------------------------------------------------------------------------------------
   case (iLookStat%inst)                              ! * instantaneous value 
    tstat(iFreq) = tdata                              !     - data at a given time
   case (iLookStat%totl)                              ! * summation over period                    
    tstat(iFreq) = tstat(iFreq) + tdata*data_step     !     - increment data 
   case (iLookStat%mean)                              ! * mean over period                       
    tstat(iFreq) = tstat(iFreq) + tdata               !     -  increment data
   case (iLookStat%vari)                              ! * variance over period                   
    tstat(iFreq) = tstat(iFreq) + tdata**2                     ! - E[X^2] term in var calc    
    tstat(maxVarFreq+iFreq) = tstat(maxVarFreq+iFreq) + tdata  ! - E[X]^2 term                 
   case (iLookStat%mini)                              ! * minimum over period                    
    if (tdata<tstat(iFreq)) tstat(iFreq) = tdata      !     - check value 
   case (iLookStat%maxi)                              ! * maximum over period                    
    if (tdata>tstat(iFreq)) tstat(iFreq) = tdata      !     - check value 
   case (iLookStat%mode)                              ! * mode over period (does not work)       
    tstat(iFreq) = realMissing
   ! -------------------------------------------------------------------------------------
  end select
 end do ! looping through output frequencies

 ! ---------------------------------------------
 ! finalize statistics at end of frequenncy period
 ! ---------------------------------------------
 if (finalizeStatistics) then
  do iFreq=1,maxVarFreq                                ! loop through output statistics
   if(meta%statIndex(iFreq)==integerMissing) cycle     ! don't bother if output frequency is not desired for a given variab;e
   if(meta%varType/=iLookVarType%outstat) cycle        ! only calculate stats for scalars
   select case(meta%statIndex(iFreq))                  ! act depending on the statistic
    ! -------------------------------------------------------------------------------------
    case (iLookStat%mean)                              ! * mean over period
     tstat(iFreq) = tstat(iFreq)/outFreq(iFreq)        !     - normalize sum into mean
    case (iLookStat%vari)                              ! * variance over period
     tstat(maxVarFreq+iFreq) = tstat(maxVarFreq+1)/outFreq(iFreq)            ! E[X] term
     tstat(iFreq) = tstat(iFreq)/outFreq(iFreq) - tstat(maxVarFreq+iFreq)**2 ! full variance
    ! -------------------------------------------------------------------------------------
   end select
  end do ! looping through output frequencies
 end if

 ! pack back into struc
 select type (stat)
  class is (ilength); stat%dat = int(tstat)
  class is (dlength); stat%dat = tstat
  class default;err=20;message=trim(message)//'stat type not found';return
 end select

 return
 end subroutine calc_stats

end module output_stats
