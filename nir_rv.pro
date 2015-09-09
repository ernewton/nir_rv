

;============================================
; FUNCTION DO_BARY
; get and apply heliocentric correction



FUNCTION DO_RVSHFTS, rv0, hdr, shdr, rv_std=rv_std, bc=hcorr


	; barycentric correction
	hcorr=GET_BARY(hdr)
	
	; offset from standard star
	hcorr_std=GET_BARY(shdr)
	IF NOT KEYWORD_SET(rv_std) THEN rv_std=18.2
	RVoff=rv_std-hcorr_std
	
	; heliocentric corrected absolute RV
	RV=RV0+hcorr+RVoff
	
	RETURN, rv

END




PRO NIR_RV, order, data, hdr, $
	data_tc, std, std_tc, shdr, stdrv=stdrv, $
	atrans=atrans, $
	polydegree=plorder, pixscale=pixscale, $
	spolydegree=s_plorder, spixscale=s_pixscale, $
	trange=trange, wrange=wrange, $
	shft=shft, s_shft=s_shft, rv=rv, torest=torest, $
	showplot=showplot, chi=chi, corr_range=corr_range, maxshift=maxshift, ccorr=ccorr, xcorl=xcorl, $
	contf=contf, frac=frac, sbin=sbin

	IF ~KEYWORD_SET(atrans) THEN $
		atrans=XMRDFITS('/home/enewton/pro/Spextool/data/atrans.fits',0)

	; parameter for oversampling the spectrum; value set by minimum needed for spex echelle
	oversamp=6.d
	
	; maximum shift to consider; in spex echelle, no shifts beyond 0.0006 (and very few >0.0004)
	if ~KEYWORD_SET(maxshift) THEN $
	        maxshift=0.0008
	maxshft=maxshift/pixscale*oversamp

	; some regions should be masked out
; 	IF NOT KEYWORD_SET(roi) THEN BEGIN
; 	CASE order OF
; 		0:	
; 		1:	
; 		2:	mask=[[1.2675,1.270]]
; 		3:	
; 		4:	
; 	ENDCASE
; 	ENDIF

	; first, get wavelength calibration by modeling the data
	TELL_MODEL, order, atrans, data, hdr, data_new, atrans_new=atrans_new, roi=roi, $
		plorder=plorder, trange=trange, wrange=wrange, oversamp=oversamp, $
		pixscale=pixscale, maxshft=maxshft, showplot=showplot, $
		res=res, shft=shft, origcont=origcont

	IF KEYWORD_SET(showplot) THEN BEGIN

; 		erase & multiplot, [1,2]
; 		plot, data[*,0], data[*,1]/origcont, yrange=[0,1.2], xrange=trange
; 		oplot, atrans[*,0], atrans[*,1], co=2, linestyle=0
; 		al_legend, ['unshifted, normalized data', 'original atrans'], color=[1,2], linestyle=0, /right, /bottom
; 		multiplot

		erase & multiplot, /default
		plot, data[*,0], data[*,1]/origcont,yrange=[0,1.2], xrange=trange
		oplot, data_new[*,0], data_new[*,1], co=7
		oplot, data[*,0]+shft, data[*,1]/origcont, co=5, linestyle=1
		oplot, atrans_new[*,0], atrans_new[*,1], co=2, linestyle=0
		oplot, [trange[0], trange[0]], [0,2], co=4, linestyle=2
		oplot, [trange[1], trange[1]], [0,2], co=4, linestyle=2
		al_legend, ['shifted, normalized, interpolated data', 'scaled, interpolated atrans'], color=[1,2], linestyle=0, /right, /bottom

		wait, 2

	ENDIF

	; now do RV

	; first, run wavelength calibration

	IF NOT KEYWORD_SET(std) THEN BEGIN
		std=MRDFITS('/home/enewton/Mdwarf-metallicities/irtf/data/14feb2012/proc/J0727+0513.fits',0,shdr1)
		std_tc=MRDFITS('/home/enewton/Mdwarf-metallicities/irtf/data/14feb2012/proc/J0727+0513_tc.fits',0,shdr)
		std_tc[*,0,*]=std[*,0,*]	; want to use original wavelength array
	ENDIF

	maxshft=maxshift/s_pixscale*oversamp

	; get wavelength calibration for the standaerd by modeling the data

	TELL_MODEL, order, atrans, std, shdr, std_new, atrans_new=atrans_new, roi=roi, $
	plorder=plorder, trange=trange, wrange=wrange, oversamp=oversamp, $
	pixscale=s_pixscale, maxshft=maxshft, showplot=showplot, $
	res=s_res, shft=s_shft, origcont=s_origcont

	IF KEYWORD_SET(showplot) THEN BEGIN

		erase & multiplot, /default
		plot, std[*,0], std[*,1]/s_origcont,yrange=[0,1.2], xrange=trange
		oplot, std_new[*,0], std_new[*,1], co=7
		oplot, std[*,0]+s_shft, std[*,1]/s_origcont, co=5, linestyle=1
		oplot, atrans_new[*,0], atrans_new[*,1], co=2, linestyle=0
		oplot, [trange[0], trange[0]], [0,2], co=4, linestyle=2
		oplot, [trange[1], trange[1]], [0,2], co=4, linestyle=2
		al_legend, ['shifted, normalized, interpolated data', 'scaled, interpolated atrans'], color=[1,2], linestyle=0, /right, /bottom
		
		wait, 2

	ENDIF

	; shift telluric corrected data
	data_tc_new = data_tc
	data_tc_new[*,0] = data_tc[*,0]+shft

	; shift telluric corrected standard
	std_tc_new = std_tc
	std_tc_new[*,0] = std_tc[*,0]+s_shft		

	ERN_RV, data_tc_new, std_tc_new, wrange=wrange, pixscale=pixscale, rv0=rv0, showplot=showplot, chi=chi, corr_range=corr_range, ccorr=ccorr, xcorl=xcorl, contf=contf, frac=frac, sbin=sbin

	rv=DO_RVSHFTS(rv0, hdr, shdr, bc=bc, rv_std=stdrv)
	torest=rv-bc
; 		print, 'shifts', shft, s_shft
	; shift is now the exact vector you need

	shft = shft - data_tc[*,0]*rv0/(3.e5)
; 	print, 'RVs', rv, bc, torest

END



