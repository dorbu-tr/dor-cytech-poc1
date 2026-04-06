using AutoMapper;
using eToro.Trading.Opstool.Domain.Dto.Example;
using eToro.Trading.Opstool.Domain.Entities.Example;

namespace eToro.Trading.Opstool.Application.Mapper;

public sealed class ExampleMappingProfile : Profile
{
    public ExampleMappingProfile()
    {
        CreateMap<ExampleDto, ExampleEntity>()
            .ForMember(dest => dest.Id, opt => opt.MapFrom(src => src.ExampleId));

        CreateMap<ExampleEntity, ExampleDto>()
            .ForMember(dest => dest.ExampleId, opt => opt.MapFrom(src => src.Id));
    }
}
