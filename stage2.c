/*
* Creating stage-2 page table for PL1&0, these page table data will be stored in reserved memory
* which have been reserved prior to calling this function.
*
*
*/
void stage2_forPL01_init(void)          /* totally need 8MB = 2^2 * 2^9 * 2^9 * 8bytes, but occupied 16MB */
{
    unsigned long pt1_e = 0, pt2_e = 0, pt3_e = 0;

    pt1_e = 0x3a000000;                     /* PT base address */
    pt2_e = pt1_e + 4096;
    pt3_e = 0x3a400000;                     /* PT entry1 base address               //manage 0x0~0x400000 */

    unsigned long long* dpt1_e = (unsigned long long *)pt1_e;

//	*(unsigned int *)(0x3af10000) = 0x50a00a05 ;

    int i = 0;
    unsigned long t = pt1_e;
    unsigned long tt = pt2_e;
    unsigned long ttt = pt3_e;

    for(i = 0; i < 4; i++)
    {      
	    dpt1_e[i] = 0;
	   
	    dpt1_e[i] = (tt & 0xfffff000U) | 0x3;  
	           
	    unsigned long long* dpt2_e = (unsigned long long *)pt2_e;

	    int j = 0;
	    for(j = 0; j < 512; j++)
	    {
	        dpt2_e[j] = 0;
	        dpt2_e[j] = (ttt & 0xfffff000U) | 0x3;
	       
	        unsigned long long* dpt3_e = (unsigned long long*)ttt;

	        int k = 0;
	        for(k = 0; k < 512; k++)
	        {
                dpt3_e[k] = 0;
                dpt3_e[k] = (((unsigned long long) i) << 30) | (((unsigned long long) j) << 21) | (((unsigned long long) k) << 12);

                if ((0x3A000000 <= dpt3_e[k]) && (dpt3_e[k] < 0x3AFE0000))                                      /* the boundary of the physical memory locked */
                        dpt3_e[k] = dpt3_e[k] | 0x47f | (((unsigned long long) 0x1) << 52);             /* 0x47f        writes to stage-2 PT are not permitted */
                else if ((0x3AFE0000<=dpt3_e[k]) && (dpt3_e[k] < 0x3AFF0000))
                		dpt3_e[k] = dpt3_e[k] | 0x43f | (((unsigned long long) 0x1) << 52);	
//                else if ((0x3af09000<=dpt3_e[k]) && (dpt3_e[k] < 0x3AF0A000))
//                		dpt3_e[k] = dpt3_e[k] | 0x43f | (((unsigned long long) 0x1) << 52);	

//                else if (0x3F300000 == dpt3_e[k])		// EMMC registers
//                		dpt3_e[k] = dpt3_e[k] | 0x43f | (((unsigned long long) 0x1) << 52);	

                else
                        dpt3_e[k] = dpt3_e[k] | 0x4ff | (((unsigned long long) 0x1) << 52);
	        }
	        ttt = ttt + 4096;
	    }
	    pt2_e = pt2_e + 4096;
	    tt = tt + 4096;
    }
}
